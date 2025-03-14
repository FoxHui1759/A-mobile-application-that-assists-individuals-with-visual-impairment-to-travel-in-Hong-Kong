from flask import Flask, render_template
from flask_socketio import SocketIO, emit
import base64


app = Flask(__name__)
socketio = SocketIO(app)


@socketio.on("connect")
def handle_connect():
    print("Client connected")
    socketio.emit("message", "Hello from the server")


@socketio.on("message")
def handle_message(data):
    print(f"Received message: {data}")


@socketio.on("initiate")
def handle_initiate(data):
    print(f"Received initiate: {data}")
    socketio.emit("ready", "Ready to receive image")


@socketio.on("image")
def handle_image(data):
    print("Received image")
    image = base64.b64decode(data)
    with open("test.png", "wb") as f:
        f.write(image)
    socketio.emit("ready", "Ready to receive image")


if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=9999)
