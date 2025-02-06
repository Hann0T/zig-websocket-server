const socket = new WebSocket("ws://127.0.0.1:3000/chat");

socket.onopen = (event) => {
    console.log("Connection opened", event);
    socket.send("ping");
};
socket.onmessage = (event) => {
    console.log("message from server", event.data);
};
socket.onclose = (event) => {
    console.log("Connection closed", event);
};
socket.onerror = (event) => {
    console.log("Connection error", event);
};

//socket.addEventListener("open", event => {
//    console.log("Connection opened", event);
//    socket.send("ping");
//})

//socket.addEventListener("message", event => {
//    console.log("message from server", event.data);
//})
//socket.addEventListener("close", event => {
//    console.log("Connection closed", event);
//})
//
//socket.addEventListener("error", event => {
//    console.log("Connection error", event);
//})
