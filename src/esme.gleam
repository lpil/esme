import gleam/io
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import gpsd_json
import node_socket_client as socket
import plinth/javascript/global
import plinth/node/process

pub fn main() {
  io.println("Connecting")

  // Connect to GPSD
  let socket = socket.connect("localhost", 2947, Nil, handle_socket_event)

  // Give up if it does not succeed within 2 seconds
  global.set_timeout(2000, fn() {
    io.println("Timeout reached, shutting down")
    socket.end(socket)
    process.exit(1)
  })
}

fn handle_socket_event(
  state: state,
  socket: socket.SocketClient,
  event: socket.Event(String),
) -> state {
  case event {
    socket.ReadyEvent -> handle_ready(state, socket)
    socket.DataEvent(data) -> handle_data(state, socket, data)
    _ -> state
  }
}

fn handle_ready(state: state, socket: socket.SocketClient) -> state {
  io.println("Socket connected, requesting data")

  let command =
    gpsd_json.command_to_string(gpsd_json.WatchCommand(
      enable: Some(True),
      json: Some(False),
    ))
  socket.write(socket, command)

  let command = gpsd_json.command_to_string(gpsd_json.PollCommand)
  socket.write(socket, command)

  state
}

fn handle_data(state: state, socket: socket.SocketClient, data: String) -> state {
  case find_coordinates(data) {
    Ok(coordinates) -> {
      io.debug(coordinates)
      socket.end(socket)
      io.println("Done")
      process.exit(0)
      state
    }

    Error(_) -> {
      io.println("Coordinates not received, requesting more data")
      let command = gpsd_json.command_to_string(gpsd_json.PollCommand)
      socket.write(socket, command)
      state
    }
  }
}

type Coordinates {
  Coordinates(time: String, latitude: Float, longitude: Float)
}

fn find_coordinates(data: String) -> Result(Coordinates, Nil) {
  let lines = string.split(data, "\n")
  use line <- list.find_map(lines)

  let response = case json.decode(line, gpsd_json.decode_response) {
    Ok(data) -> data
    Error(_) -> panic as { "Invalid JSON message: " <> data }
  }

  use #(time, tpvs) <- result.try(case response {
    gpsd_json.PollResponse(time: time, tpv: tpv, ..) -> Ok(#(time, tpv))
    _ -> Error(Nil)
  })

  use tpv <- list.find_map(tpvs)

  case tpv.latitude, tpv.longitude {
    Some(lat), Some(lon) ->
      Ok(Coordinates(time: time, latitude: lat, longitude: lon))
    _, _ -> Error(Nil)
  }
}
