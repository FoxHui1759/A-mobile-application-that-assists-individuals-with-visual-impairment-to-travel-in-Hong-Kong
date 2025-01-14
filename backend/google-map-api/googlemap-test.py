import requests
import os
import re
import json
from dotenv import load_dotenv
from typing import Tuple, List
import math

load_dotenv()


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


def get_place_location(place_name: str, api_key: str, use_geocoding: bool = True) -> str:
    """
    Search for a place using the Google Places API or Geocoding API as a fallback.
    Returns the formatted address if found, else raises ValueError.
    """
    place_url = "https://maps.googleapis.com/maps/api/place/findplacefromtext/json"
    params = {
        'input': f"{place_name}, Hong Kong",
        'inputtype': 'textquery',
        'fields': 'formatted_address,name,geometry',
        'language': 'zh-TW',
        'key': api_key
    }

    try:
        response = requests.get(place_url, params=params)
        result = response.json()

        if result.get('status') == 'OK' and len(result.get('candidates', [])) > 0:
            place = result['candidates'][0]
            return place['formatted_address']
        elif use_geocoding:
            # Use Geocoding as fallback
            geocode_url = "https://maps.googleapis.com/maps/api/geocode/json"
            params = {
                'address': f"{place_name}, Hong Kong",
                'key': api_key,
                'region': 'hk',
                'language': 'zh-TW'
            }
            response = requests.get(geocode_url, params=params)
            result = response.json()

            if result.get('status') == 'OK' and len(result.get('results', [])) > 0:
                return result['results'][0]['formatted_address']

        raise ValueError(f"Location not found: {place_name}")

    except Exception as e:
        raise ValueError(f"Error finding place: {str(e)}")


def preprocess_coordinates(location: str, api_key: str) -> str:
    """
    If `location` is lat,lng coordinates, convert to a proper place name via reverse geocoding.
    Otherwise, fetch the place name using get_place_location().
    """
    is_coord, coords = is_coordinates(location)
    if is_coord:
        # Use reverse geocoding for coordinates
        geocode_url = "https://maps.googleapis.com/maps/api/geocode/json"
        params = {
            'latlng': f"{coords[0]},{coords[1]}",
            'key': api_key,
            'region': 'hk',
            'language': 'zh-TW'
        }
        response = requests.get(geocode_url, params=params)
        result = response.json()

        if result.get('status') == 'OK' and len(result.get('results', [])) > 0:
            return result['results'][0]['formatted_address']
        else:
            raise ValueError(f"No valid address found for coordinates: {location}")
    else:
        return get_place_location(location, api_key)


def decode_polyline(polyline_str: str) -> List[Tuple[float, float]]:
    """
    Decodes a polyline that encodes a series of lat/lng points.
    Returns a list of (latitude, longitude) tuples.
    Reference: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
    """
    points = []
    index, lat, lng = 0, 0, 0
    while index < len(polyline_str):
        shift, result = 0, 0
        while True:
            b = ord(polyline_str[index]) - 63
            index += 1
            result |= (b & 0x1f) << shift
            shift += 5
            if b < 0x20:
                break
        dlat = ~(result >> 1) if (result & 1) else (result >> 1)
        lat += dlat

        shift, result = 0, 0
        while True:
            b = ord(polyline_str[index]) - 63
            index += 1
            result |= (b & 0x1f) << shift
            shift += 5
            if b < 0x20:
                break
        dlng = ~(result >> 1) if (result & 1) else (result >> 1)
        lng += dlng

        points.append((lat / 1e5, lng / 1e5))
    return points


def compute_route_slope(route_polyline: str, api_key: str) -> float:
    """
    Compute an *approximate* slope factor for the entire route based on
    elevation differences between sampled points.
    """
    points = decode_polyline(route_polyline)
    if len(points) < 2:
        return 0.0  # No slope if there's only one or no point

    # Elevation API (batch request)
    elevation_url = "https://maps.googleapis.com/maps/api/elevation/json"
    # Sample every nth point to limit API calls
    step_size = 5
    sampled_points = points[::step_size]
    locations_str = "|".join([f"{p[0]},{p[1]}" for p in sampled_points])

    params = {
        'locations': locations_str,
        'key': api_key
    }
    try:
        response = requests.get(elevation_url, params=params)
        elevation_data = response.json()
        if elevation_data.get('status') != 'OK':
            return 0.0

        elevations = [res['elevation'] for res in elevation_data['results']]
    except Exception:
        # If something goes wrong (e.g. network error), just return 0
        return 0.0

    total_slope = 0.0
    segment_count = 0

    for i in range(len(elevations) - 1):
        delta_elevation = elevations[i+1] - elevations[i]
        # approximate horizontal distance between sampled points
        lat1, lng1 = sampled_points[i]
        lat2, lng2 = sampled_points[i+1]

        # Very rough approximation for horizontal distance in meters
        dist_lat = (lat2 - lat1) * 111_111
        avg_lat = (lat1 + lat2) / 2
        dist_lng = (lng2 - lng1) * 111_111 * abs(math.cos(math.radians(avg_lat)))
        horizontal_dist = math.sqrt(dist_lat**2 + dist_lng**2)

        if horizontal_dist > 0:
            slope = (delta_elevation / horizontal_dist) * 100.0  # slope in %
        else:
            slope = 0.0

        total_slope += abs(slope)
        segment_count += 1

    avg_slope = total_slope / max(1, segment_count)
    return avg_slope


def flatten_steps(steps: List[dict]) -> List[dict]:
    """
    Google Directions API can nest sub-steps. This helper function flattens them 
    so we don't get repeated instructions or step indices.
    """
    flattened = []
    for step in steps:
        if 'steps' in step and isinstance(step['steps'], list) and step['steps']:
            # If this step has sub-steps, flatten them recursively
            flattened.extend(flatten_steps(step['steps']))
        else:
            flattened.append(step)
    return flattened


def evaluate_routes(routes_data: List[dict], api_key: str) -> dict:
    """
    Evaluate each route based on multiple factors:
      1) Travel Time (shorter is better)
      2) Slope (lower is better)
      3) Number of Steps (fewer instructions is better)
      4) Number of Turns (fewer is better for visually impaired)
    Returns the single 'best' route (dict) with the lowest calculated 'score'.
    """
    best_route = None
    best_score = float('inf')

    print("Evaluating routes...")

    for idx, route in enumerate(routes_data):
        if not route.get('legs'):
            continue  # skip if no legs

        leg = route['legs'][0]  # For walking, typically 1 leg
        steps = leg.get('steps', [])

        # Flatten sub-steps to avoid duplicate instructions
        steps = flatten_steps(steps)

        # Travel time in seconds
        travel_time = leg['duration']['value'] if 'duration' in leg else 999999

        # Number of (flattened) steps
        step_count = len(steps)

        # Count "turn" instructions as a proxy for complexity
        turn_count = 0
        for s in steps:
            html_instructions = s.get('html_instructions', '').lower()
            if 'turn' in html_instructions:
                turn_count += 1

        # Compute slope
        overview_polyline = route.get('overview_polyline', {}).get('points', '')
        slope_factor = 0.0
        if overview_polyline:
            slope_factor = compute_route_slope(overview_polyline, api_key)

        # Weighted scoring
        time_weight = 1.0
        slope_weight = 2.0
        step_weight = 0.5
        turn_weight = 0.75

        score = (time_weight * travel_time) + \
                (slope_weight * slope_factor) + \
                (step_weight * step_count) + \
                (turn_weight * turn_count)

        print(f"Route #{idx + 1} -> "
              f"Time: {travel_time}s, Steps: {step_count}, Turns: {turn_count}, "
              f"Slope: {slope_factor:.2f}, Score: {score:.2f}")

        # Update best route if this one is better
        if score < best_score:
            best_score = score
            best_route = route

    print(f"\nBest score: {best_score:.2f}\n" if best_score != float('inf') else "\nNo valid routes found.\n")
    return best_route


def google_map_path(origin: str, destination: str, api_key: str):
    """
    Query the Google Directions API for a walking route from origin to destination
    and pick the best route based on custom criteria.
    """
    print(f"Getting the path from {origin} to {destination}...")

    url = "https://maps.googleapis.com/maps/api/directions/json"
    params = {
        'origin': origin,
        'destination': destination,
        'mode': 'walking',
        'departure_time': 'now',
        'alternatives': 'true',
        'language': 'zh-HK',
        'key': api_key
    }

    try:
        response = requests.get(url, params=params)
        res = response.json()
    except Exception as e:
        print(f"Error calling Directions API: {e}")
        return

    if res.get('status') == "OK":
        routes = res.get('routes', [])
        print(f"Number of routes returned by Directions API: {len(routes)}")

        if not routes:
            print("No routes found. Please try different locations.")
            return

        # Evaluate and pick best route
        best_route = evaluate_routes(routes, api_key)
        if not best_route:
            print("No suitable route found after evaluation.")
            return

        # Identify chosen route index
        chosen_index = routes.index(best_route)
        print(f"Chosen Route Index: {chosen_index + 1} (0-based index: {chosen_index})")

        # Flatten final route steps
        legs = best_route.get('legs', [])
        if not legs:
            print("No legs in the chosen route.")
            return

        steps = legs[0].get('steps', [])
        steps = flatten_steps(steps)

        # Save route to JSON
        output_data = {
            'selected_route': best_route,
            'all_routes': res['routes']
        }
        with open('google_map_path.json', 'w', encoding='utf-8') as f:
            json.dump(output_data, f, indent=4, ensure_ascii=False)

        print(f"================== Best Route from {origin} to {destination} ==================")
        for i, step in enumerate(steps):
            dist = step.get('distance', {}).get('text', 'N/A')
            dur = step.get('duration', {}).get('text', 'N/A')
            start_loc = step.get('start_location', {})
            end_loc = step.get('end_location', {})
            instructions_raw = step.get('html_instructions', '')

            # Clean up HTML in instructions
            instructions = instructions_raw.replace("<b>", "**").replace("</b>", "**")
            instructions = instructions.replace("<div style=\"font-size:0.9em\">", ", ").replace("</div>", "")

            print(f"Step {i + 1}: {instructions}")
            print(f"Distance: {dist}")
            print(f"Duration: {dur}")
            print(f"Start location: {start_loc}")
            print(f"End location: {end_loc}")
            print("------------")

        print("=============================================================")

    else:
        print("Directions API returned an error:")
        print(json.dumps(res, indent=2, ensure_ascii=False))


def main():
    api_key = os.getenv("GOOGLE_MAP_API_KEY")
    if not api_key:
        print("Error: GOOGLE_MAP_API_KEY not found in environment.")
        return

    try:
        # Hardcoded start coords for demo:
        start_coord = (22.2835513, 114.1345991)
        end_location = input("Enter the destination: ").strip()

        # Convert start coordinates to an address (reverse-geocode)
        start_location = preprocess_coordinates(",".join(map(str, start_coord)), api_key)

        print(f"Processed start location: {start_location}")
        print(f"Processed end location: {end_location}")

        # Get path using processed locations
        google_map_path(start_location, end_location, api_key)

    except ValueError as e:
        print(f"ValueError: {str(e)}")
    except Exception as e:
        print(f"Unexpected error: {str(e)}")


if __name__ == "__main__":
    main()
