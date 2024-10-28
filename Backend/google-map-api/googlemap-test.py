# google map path from point a to point b
# input: two points a and b
# output: the path from a to b

import googlemaps
from dotenv import load_dotenv
import os

load_dotenv()

def google_map_path(a, b):
    # set up the google map API
    gmaps = googlemaps.Client(key=os.getenv("GOOGLE_MAP_API_KEY"))
    print(f"Getting the path from {a} to {b}...")

    # get the direction from point a to point b with disabled friendly path
    res = gmaps.directions(a, b, mode="walking", departure_time="now", alternatives=True)

    print(res)
    # print the path in a readable format
    for i, step in enumerate(res[0]['legs'][0]['steps']):
        print(f"Step {i + 1}: {step['html_instructions']}")
        print(f"Distance: {step['distance']['text']}")
        print(f"Duration: {step['duration']['text']}")
        print(f"Start location: {step['start_location']}")
        print(f"End location: {step['end_location']}")

        # also print the path in markdown format
        instructions = step['html_instructions']
        instructions = instructions.replace("<b>", "**")
        instructions = instructions.replace("</b>", "**")
        instructions = instructions.replace("<div style=\"font-size:0.9em\">", ", ")
        instructions = instructions.replace("</div>", "")

        print(f"Path: {instructions}")

        print("\n")

# test the function
google_map_path("Victoria Peak, Hong Kong", "Central, Hong Kong")

# TODO: find a way to change the input into google map readable format
# a = input("Enter the starting point: ")
# b = input("Enter the destination point: ")
# google_map_path(a, b)