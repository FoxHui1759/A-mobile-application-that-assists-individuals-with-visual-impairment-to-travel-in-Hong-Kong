# google map path from point a to point b
# input: two points a and b
# output: the path from a to b

import googlemaps
from dotenv import load_dotenv
import os

load_dotenv()


# find the location of a place
def find_location(location: str, gmaps_client: googlemaps.Client) -> str:
    """
    Find the location of a place
    :param location: location input
    :param gmaps_client: Google Map client
    :return: a proper location name
    """

    # find a proper location name
    res = googlemaps.geocode(location)
    print(res)
    print(f"Location: {res[0]['formatted_address']}")
    print(f"Latitude: {res[0]['geometry']['location']['lat']}")
    print(f"Longitude: {res[0]['geometry']['location']['lng']}")
    print("\n")

    return res[0]["formatted_address"]


def google_map_path(a: str, b: str, gmaps: googlemaps.Client):
    """
    Get the path from point a to point b
    :param a: Starting point
    :param b: Destination point
    :param gmaps: Google map client
    :return: None
    """
    # set up the google map API
    print(f"Getting the path from {a} to {b}...")

    # get the direction from point a to point b with disabled friendly path
    res = gmaps.directions(
        a, b, mode="walking", departure_time="now", alternatives=True, language="zh-HK"
    )

    print(res)
    # print the path in a readable format
    for i, step in enumerate(res[0]["legs"][0]["steps"]):
        print(f"Step {i + 1}: {step['html_instructions']}")
        print(f"Distance: {step['distance']['text']}")
        print(f"Duration: {step['duration']['text']}")
        print(f"Start location: {step['start_location']}")
        print(f"End location: {step['end_location']}")

        # also print the path in markdown format
        instructions = step["html_instructions"]
        instructions = instructions.replace("<b>", "**")
        instructions = instructions.replace("</b>", "**")
        instructions = instructions.replace('<div style="font-size:0.9em">', ", ")
        instructions = instructions.replace("</div>", "")

        print(f"Path: {instructions}")

        print("\n")


def main():
    google_map_client = googlemaps.Client(
        key=os.getenv("AIzaSyB5W2CdEHJ3LTlIeSJz0uN8lIU2fZI7Nto")
    )
    print("Google Map API is set up")
    # test the function
    google_map_path("Victoria Peak, Hong Kong", "Central, Hong Kong", google_map_client)

    # TODO: find a way to change the input into google map readable format
    # a = input("Enter the starting point: ")
    # b = input("Enter the destination point: ")
    # google_map_path(a, b)


main()
