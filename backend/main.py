from flask import Flask, render_template
from flask_socketio import SocketIO, emit

app = Flask(__name__)
socketio = SocketIO(app)


@socketio.on("connect")
def handle_connect():
    print("Client connected")
    socketio.emit("message", "Hello from the server")


if __name__ == "__main__":
    socketio.run(app)
