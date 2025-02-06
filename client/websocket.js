const socket = new WebSocket("ws://localhost:3000/chat");

socket.addEventListener("open", event => {
    console.log("Connection opened", event);
    socket.send("ping");
})
socket.addEventListener("message", event => {
    console.log("message from server", event.data);
})
socket.addEventListener("close", event => {
    console.log("Connection closed", event);
})

socket.addEventListener("error", event => {
    console.log("Connection error", event);
})
