import requests
import os
import re
import json
from dotenv import load_dotenv

load_dotenv()

def is_coordinates(location: str) -> tuple:
    """Check if location string is in latitude,longitude format."""
    coord_pattern = r'^(-?\d+\.?\d*),\s*(-?\d+\.?\d*)$'
    match = re.match(coord_pattern, location.strip())
    if match:
        lat, lng = map(float, match.groups())
        if -90 <= lat <= 90 and -180 <= lng <= 180:
            return True, (lat, lng)
    return False, None


def get_place_location(place_name: str, api_key: str, use_geocoding: bool = True) -> str:
    """
    Search for a place using Google Places API
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
        
        if result['status'] == 'OK':
            place = result['candidates'][0]
            return place['formatted_address']
        elif use_geocoding:
            # Use geocoding as fallback
            geocode_url = "https://maps.googleapis.com/maps/api/geocode/json"
            params = {
                'address': f"{place_name}, Hong Kong",
                'key': api_key,
                'region': 'hk',
                'language': 'zh-TW'
            }
            response = requests.get(geocode_url, params=params)
            result = response.json()
            
            if result['status'] == 'OK':
                return result['results'][0]['formatted_address']
                
        raise ValueError(f"Location not found: {place_name}")
            
    except Exception as e:
        raise ValueError(f"Error finding place: {str(e)}")


def preprocess_coordinates(location: str, api_key: str) -> str:
    """
    Convert coordinates to a proper location name using reverse geocoding.
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
        
        if result['status'] == 'OK':
            return result['results'][0]['formatted_address']
        else:
            print(result)
            raise ValueError(f"Location not found for coordinates: {location}")
    else:
        return get_place_location(location, api_key)


def google_map_path(a: str, b: str, api_key: str):
    """
    Get the path from point a to point b using coordinates.

    :param a: Starting point
    :param b: Destination point
    :param api_key: Google Maps API key
    :return: None
    """
    print(f"Getting the path from {a} to {b}...")

    url = "https://maps.googleapis.com/maps/api/directions/json"
    params = {
        'origin': a,
        'destination': b,
        'mode': 'walking',
        'departure_time': 'now',
        'alternatives': 'true',
        'language': 'zh-HK',
        'key': api_key
    }

    response = requests.get(url, params=params)
    res = response.json()

    if res['status'] == "OK":
        # Print the path in a readable format
        print(f"==================== Path from {a} to {b} ====================")
        steps = res['routes'][0]['legs'][0]['steps']
        # save the path to a json file beautified in UTF-8
        with open('google_map_path.json', 'w') as f:
            json.dump(res, f, indent=4, ensure_ascii=False)

        # print path to console
        for i, step in enumerate(steps):
            print(f"Step {i + 1}: {step['html_instructions']}")
            print(f"Distance: {step['distance']['text']}")
            print(f"Duration: {step['duration']['text']}")
            print(f"Start location: {step['start_location']}")
            print(f"End location: {step['end_location']}")

            # Format instructions for markdown output
            instructions = step['html_instructions']
            instructions = instructions.replace("<b>", "**").replace("</b>", "**")
            instructions = instructions.replace("<div style=\"font-size:0.9em\">", ", ").replace("</div>", "")

            print(f"Path: {instructions}\n")

        print("=============================================================")
    else:
        print("Error:", res['status'])


def main():
    api_key = os.getenv("GOOGLE_MAP_API_KEY")

    try:
        # Get user input for coordinates
        # a = input("Enter the starting point (latitude,longitude): ")
        start_coord = (22.2835513, 114.1345991)
        end_location = input("Enter the destination: ")

        # Preprocess coordinates to get formatted addresses (if needed)
        start_location = preprocess_coordinates(",".join(map(str, start_coord)), api_key)

        print(f"Processed start location: {start_location}")
        print(f"Processed end location: {end_location}")

        # Get path using processed locations
        google_map_path(start_location, end_location, api_key)

    except ValueError as e:
        print(f"Error: {str(e)}")
    except Exception as e:
        print(f"Unexpected error: {str(e)}")


if __name__ == "__main__":
    main()
