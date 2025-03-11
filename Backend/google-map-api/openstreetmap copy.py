import requests
import os
import re
import json
import math
from dotenv import load_dotenv
from typing import Tuple, List

load_dotenv()

##############################################################################
#                              HELPER FUNCTIONS                              #
##############################################################################

def is_coordinates(location: str) -> Tuple[bool, Tuple[float, float]]:
    """
    Check if the location string is in latitude,longitude format.
    Returns (True, (lat, lng)) if valid; otherwise (False, (0.0, 0.0)).
    """
    coord_pattern = r'^(-?\d+\.?\d*),\s*(-?\d+\.?\d*)$'
    match = re.match(coord_pattern, location.strip())
    if match:
        lat, lng = map(float, match.groups())
        if -90 <= lat <= 90 and -180 <= lng <= 180:
            return True, (lat, lng)
    return False, (0.0, 0.0)

def get_place_coordinates(place_name: str, ors_api_key: str) -> Tuple[float, float]:
    """
    Forward geocoding via ORS.
    Returns (lat, lng).
    Raises ValueError if not found.
    """
    url = "https://api.openrouteservice.org/geocode/search"
    headers = {"Authorization": ors_api_key}
    params = {
        "text": place_name,
        "size": 1,         # only need one best match
        "boundary.country": "HK",  # or remove/modify if you want wider search
    }
    try:
        resp = requests.get(url, headers=headers, params=params)
        data = resp.json()
        features = data.get("features", [])
        if not features:
            raise ValueError(f"Location not found: {place_name}")
        
        coords = features[0]["geometry"]["coordinates"]  # [lng, lat]
        lng, lat = coords
        return (lat, lng)
    except Exception as e:
        raise ValueError(f"Error finding place '{place_name}': {e}")

def get_address_from_coordinates(lat: float, lng: float, ors_api_key: str) -> str:
    """
    Reverse geocoding via ORS.
    Returns an address string or raises ValueError if not found.
    """
    url = "https://api.openrouteservice.org/geocode/reverse"
    headers = {"Authorization": ors_api_key}
    params = {
        "point.lat": lat,
        "point.lon": lng,
        "size": 1,
    }
    try:
        resp = requests.get(url, headers=headers, params=params)
        data = resp.json()
        features = data.get("features", [])
        if not features:
            raise ValueError(f"No address found for coordinates: ({lat}, {lng})")
        address = features[0]["properties"].get("label", "")
        return address
    except Exception as e:
        raise ValueError(f"Error reverse-geocoding coords ({lat}, {lng}): {e}")

def preprocess_coordinates(location: str, ors_api_key: str) -> Tuple[float, float]:
    """
    If `location` is lat,lng coordinates, convert to a proper place name via reverse geocoding
    (i.e. just confirm we have valid coords). Otherwise do forward geocoding.
    Returns (lat, lng).
    """
    is_coord, coords = is_coordinates(location)
    if is_coord:
        # Already valid coordinates
        return coords
    else:
        # Forward geocoding
        return get_place_coordinates(location, ors_api_key)

def get_elevations_along_line(points: List[Tuple[float, float]], ors_api_key: str) -> List[float]:
    """
    Use ORS's Elevation Line service to get elevations for a series of points.
    Points must be in [lon, lat] order. 
    Returns a list of elevation values. If error, returns a list of 0's.
    """
    # ORS line endpoint expects GeoJSON with coordinates in [lon, lat]
    coords = []
    for (lat, lng) in points:
        coords.append([lng, lat])  # reorder to [lon, lat]

    url = "https://api.openrouteservice.org/elevation/line"
    headers = {"Authorization": ors_api_key, "Content-Type": "application/json"}
    payload = {
        "format_in": "polyline",
        "format_out": "json",
        "geometry": {
            "type": "LineString",
            "coordinates": coords
        }
    }

    try:
        resp = requests.post(url, headers=headers, json=payload)
        data = resp.json()

        # "geometry" => "coordinates" => [ [lon, lat, ele], [lon, lat, ele], ... ]
        new_coords = data.get("geometry", {}).get("coordinates", [])
        if not new_coords:
            return [0.0]*len(points)

        # Each element is [lon, lat, elevation]
        elevations = [pt[2] for pt in new_coords]
        return elevations
    except Exception:
        return [0.0]*len(points)

def compute_route_slope(coordinates: List[Tuple[float, float]], ors_api_key: str) -> float:
    """
    Approximate slope factor using sampled elevation differences. 
    `coordinates` is a list of (lat, lng) points in sequence.
    We will:
     1) Sub-sample these points
     2) Get elevation from ORS
     3) Compute average slope in %
    """
    # Sample every nth point to limit calls
    step_size = 5
    sampled_points = coordinates[::step_size]

    # Get elevation for each point
    elevations = get_elevations_along_line(sampled_points, ors_api_key)
    if not elevations or len(elevations) < 2:
        return 0.0

    total_slope = 0.0
    segment_count = 0

    for i in range(len(elevations) - 1):
        delta_elev = elevations[i+1] - elevations[i]
        lat1, lng1 = sampled_points[i]
        lat2, lng2 = sampled_points[i+1]

        # Approx horizontal distance in meters (rough)
        dist_lat = (lat2 - lat1) * 111_111
        avg_lat = (lat1 + lat2) / 2
        dist_lng = (lng2 - lng1) * 111_111 * abs(math.cos(math.radians(avg_lat)))
        horiz_dist = math.sqrt(dist_lat**2 + dist_lng**2)

        if horiz_dist > 0:
            slope_percent = (delta_elev / horiz_dist) * 100.0
        else:
            slope_percent = 0.0

        total_slope += abs(slope_percent)
        segment_count += 1

    return total_slope / max(1, segment_count)

def flatten_steps_ors(steps: List[dict]) -> List[dict]:
    """
    ORS 'steps' typically don't have nested sub-steps like Google,
    so here we can just return them as-is. 
    But if you want a single list with no nested structure, you can adapt as needed.
    """
    # In OpenRouteService, steps are generally already "flat."
    return steps

##############################################################################
#                   CORE LOGIC: Directions + Route Evaluation                #
##############################################################################

def ors_directions(origin: Tuple[float, float],
                   destination: Tuple[float, float],
                   ors_api_key: str,
                   alternative_routes: bool = True) -> dict:
    """
    Query the ORS Directions API for a walking route from origin to destination.
    Return the entire JSON. We'll parse out the routes ourselves.
    `origin` and `destination` are (lat, lng).
    """
    url = "https://api.openrouteservice.org/v2/directions/foot-walking"
    headers = {"Authorization": ors_api_key, "Content-Type": "application/json"}

    # ORS expects [lon, lat]
    payload = {
        "coordinates": [
            [origin[1], origin[0]],      # [lon, lat]
            [destination[1], destination[0]]
        ],
        # If you want to request multiple alternatives, you can specify
        # "options": {"alternatives": True}, 
        # but ORS doesn't always return multiple distinct routes for walking
    }
    if alternative_routes:
        # This attempts to find alternative routes, though availability is limited
        payload["options"] = {"alternative_routes": {"share_factor": 0.8, "target_count": 2}}

    try:
        resp = requests.post(url, headers=headers, json=payload)
        data = resp.json()
        # "features" is the array of route(s)
        return data
    except Exception as e:
        raise ValueError(f"Error calling ORS Directions: {e}")

def evaluate_routes(ors_data: dict, ors_api_key: str) -> dict:
    """
    Evaluate each returned route from ORS data. Weighted scoring:
      1) Travel Time (shorter is better)
      2) Slope (lower is better)
      3) Number of Steps (fewer is better)
      4) Number of Turns (fewer is better)
    Returns the single 'best' route (a feature from ORS) with the lowest 'score'.
    """
    features = ors_data.get("features", [])
    if not features:
        print("No routes found in ORS data.")
        return {}

    best_route = None
    best_score = float('inf')

    print("Evaluating routes from ORS...")

    for idx, feature in enumerate(features):
        props = feature.get("properties", {})
        segments = props.get("segments", [])

        if not segments:
            continue

        # For walking, typically 1 segment, but there can be multiple.
        # We'll assume the first segment is the main one.
        main_seg = segments[0]

        travel_time = main_seg.get("duration", 999999)  # in seconds
        steps_ors = main_seg.get("steps", [])
        steps_ors = flatten_steps_ors(steps_ors)
        step_count = len(steps_ors)

        # Count "turn" instructions as a proxy for complexity
        turn_count = 0
        for s in steps_ors:
            instr = s.get("instruction", "").lower()
            if "turn" in instr:
                turn_count += 1

        # Coordinates for slope calculation:
        geometry = feature.get("geometry", {})
        coords_line = geometry.get("coordinates", [])  # array of [lon, lat]
        # Re-map them to (lat, lon) for slope function
        route_points = [(c[1], c[0]) for c in coords_line]

        slope_factor = 0.0
        if len(route_points) > 1:
            slope_factor = compute_route_slope(route_points, ors_api_key)

        # Weighted scoring
        time_weight = 1.0
        slope_weight = 2.0
        step_weight = 0.5

        score = (time_weight * travel_time) \
                + (slope_weight * slope_factor) \
                + (step_weight * step_count)

        dist_km = main_seg.get("distance", 0.0) / 1000.0
        print(f"Route #{idx+1}: Time: {travel_time:.1f}s, Dist: {dist_km:.2f}km, "
              f"Steps: {step_count}, Slope: {slope_factor:.2f}, Score: {score:.2f}")

        if score < best_score:
            best_score = score
            best_route = feature

    print(f"\nBest score: {best_score:.2f}\n" if best_score != float('inf') else "\nNo valid routes found.\n")
    return best_route

def print_best_route_details(best_route: dict):
    """
    Print out the instructions / details for the chosen route.
    """
    props = best_route.get("properties", {})
    segments = props.get("segments", [])
    if not segments:
        print("No segments in best route.")
        return

    main_seg = segments[0]
    steps_ors = main_seg.get("steps", [])
    steps_ors = flatten_steps_ors(steps_ors)

    print("================== Best Route Steps ==================")
    for i, step in enumerate(steps_ors):
        dist_m = step.get("distance", "N/A")
        dur_s = step.get("duration", "N/A")
        instruction = step.get("instruction", "")
        print(f"Step {i+1}: {instruction}")
        print(f"Distance: {dist_m} m, Duration: {dur_s} s")
        print("-------------------------------------------------")
    print("=================================================")

##############################################################################
#                                   MAIN                                     #
##############################################################################

def main():
    ors_api_key = os.getenv("OPENROUTESERVICE_API_KEY")
    if not ors_api_key:
        print("Error: ORS_API_KEY not found in environment.")
        return

    try:
        # Hardcoded start coords for demo:
        start_coord = (22.2835513, 114.1345991)  # (lat, lng)
        end_location = input("Enter the destination: ").strip()

        # Preprocess origin (already lat, lng) 
        # but let's confirm it's valid / do reverse if needed
        # or skip if you know start_coord is correct
        # start_coord = preprocess_coordinates(",".join(map(str, start_coord)), ors_api_key)

        # Preprocess end location
        end_coord = preprocess_coordinates(end_location, ors_api_key)

        print(f"Processed start location: {start_coord}")
        print(f"Processed end location: {end_coord}")

        # Get routes from ORS
        ors_result = ors_directions(start_coord, end_coord, ors_api_key, alternative_routes=True)

        # Evaluate and pick best route
        best_route = evaluate_routes(ors_result, ors_api_key)
        if not best_route:
            print("No suitable route found after evaluation.")
            return

        # Print route instructions
        print_best_route_details(best_route)

        # Optionally, save the entire result to JSON
        output_data = {
            'selected_route': best_route,
            'all_routes': ors_result.get('features', [])
        }
        with open('ors_map_path.json', 'w', encoding='utf-8') as f:
            json.dump(output_data, f, indent=4, ensure_ascii=False)

    except ValueError as e:
        print(f"ValueError: {str(e)}")
    except Exception as e:
        print(f"Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()
