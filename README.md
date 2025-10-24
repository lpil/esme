# Esme

A Gleam program that runs on NodeJS. It starts, connects to GPSD on
`127.0.0.1:2947`, pulls the latest GPS data, and appends the timestamp and
coordinates to a CSV file named after the date of the timestamp.

If it is unable to get the coordinates within 5 seconds it exits with en error.

To use this program you must first install GPSD on your machine and ensure it
is running. It is likely available with your Linux distro's package manager.
Ensure that it can connect to your USB GPS receiver.

The recommended way to run the program itself is inside a container, run by
Podman's systemd integration. A systemd timer can be defined to run the program
container periodically.

Ensure podman is installed on your box using the package manager.

Create a file at `/etc/containers/systemd/esme-gps.container` with these
contents, to define the systemd service that runs the program in a podman
container:

```ini
[Unit]
Description=Esme GPS data processor

[Container]
Image=ghcr.io/lpil/esme:main

# Mount host directory to container
# Adjust /srv/esme-gps to your desired host path
Volume=/srv/esme-gps:/app/data:rw

Remove=true

[Service]
# Don't restart automatically — timer controls runs
Restart=no
```

Create a file at `/etc/containers/systemd/esme-gps.timer` to define the systemd
timer which runs the service every 5 minutes:

```ini
[Unit]
Description=Run Esme GPS container every 5 minutes

[Timer]
OnCalendar=*:0/5

[Install]
WantedBy=timers.target
```

Create the data directory to store the CSV files:

```sh
sudo mkdir -p /srv/esme-data
sudo chmod 777 /srv/esme-data
```

Load the new config files and start the timer:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now esme-gps.timer
```
