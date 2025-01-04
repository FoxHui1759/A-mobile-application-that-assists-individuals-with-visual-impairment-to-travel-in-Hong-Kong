import requests
from dotenv import load_dotenv
import os

load_dotenv()

def get_accessible_route(start_coords, end_coords, api_key):
    """
    Get an accessible walking route using OpenRouteService.
    
    :param start_coords: Tuple of (latitude, longitude) for starting point
    :param end_coords: Tuple of (latitude, longitude) for destination point
    :param api_key: OpenRouteService API key
    :return: Suggested route information
    """
    url = "https://api.openrouteservice.org/v2/directions/foot-walking"
    
    headers = {
        'Authorization': api_key,
        'Accept': 'application/json, application/geo+json, application/gpx+xml, img/png'
    }
    
    body = {
        "coordinates": [
            [start_coords[1], start_coords[0]],  # [longitude, latitude]
            [end_coords[1], end_coords[0]]
        ],
        "preference": "recommended",
        "units": "m",
        "language": "en",
        "instructions": True,
        "elevation": True,
        # "options": {
        #     "avoid_features": [
        #         "steps",
        #         "steep_incline"
        #     ],
        # },
        "extra_info": ["waytype", "steepness"]
    }
    
    try:
        response = requests.post(url, json=body, headers=headers)
        response.raise_for_status()
        
        route_data = response.json()
        
        if 'routes' in route_data and len(route_data['routes']) > 0:
            
            route = route_data['routes'][0]
            
            # Format response
            formatted_response = {
                'distance': route['summary']['distance'],  # meters
                'duration': route['summary']['duration'],  # seconds
                'steps': []
            }
            
            # Extract step-by-step instructions
            for segment in route['segments']:
                for step in segment['steps']:
                    formatted_response['steps'].append({
                        'instruction': step['instruction'],
                        'distance': step['distance'],
                        'duration': step['duration']
                    })
                    
            return formatted_response
        else:
            raise Exception("No route found")
            
    except requests.exceptions.RequestException as e:
        raise Exception(f"Error fetching route: {str(e)}")
    except KeyError as e:
        raise Exception(f"Error parsing response: {str(e)}")
    except Exception as e:
        raise Exception(f"Unexpected error: {str(e)}")

def main():
    api_key = os.getenv("OPENROUTESERVICE_API_KEY")
    if not api_key:
        raise ValueError("API key not found in environment variables")
        
    # Example coordinates (HKU to Central)
    start = (22.2832728,114.1331896)  # HKU
    end = (22.2828941,114.1378027)    # Central
    
    try:
        route = get_accessible_route(start, end, api_key)
        print("\nRoute Summary:")
        print(f"Total Distance: {route['distance']/1000:.2f} km")
        print(f"Total Duration: {route['duration']/60:.0f} minutes")
        
        print("\nStep by Step Instructions:")
        for i, step in enumerate(route['steps'], 1):
            print(f"\n{i}. {step['instruction']}")
            print(f"   Distance: {step['distance']:.0f}m")
            print(f"   Duration: {step['duration']/60:.1f} minutes")
            
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    main()