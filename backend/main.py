from flask import Flask, render_template
from flask_socketio import SocketIO, emit


app = Flask(__name__)
socketio = SocketIO(app)


@socketio.on("connect")
def handle_connect():
    print("Client connected")
    socketio.emit("message", "Hello from the server")


@socketio.on("message")
def handle_message(data):
    print(f"Received message: {data}")


if __name__ == "__main__":
    socketio.run(app)
