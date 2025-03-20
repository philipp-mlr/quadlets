# quadlets

A place for my podman quadlets

## Overview

This repository contains a collection of quadlet files for managing podman containers. Quadlets are systemd unit files that simplify the management of podman containers by providing a declarative way to define and run containers.

## Getting Started

To use the quadlets in this repository, follow these steps:

1. Clone the repository:

   ```sh
   git clone https://github.com/yourusername/quadlets.git
   cd quadlets
   ```

2. Copy the desired quadlet files to the appropriate systemd directory:

   ```sh
   sudo cp *.service /etc/systemd/system/
   ```

3. Reload the systemd manager configuration:

   ```sh
   sudo systemctl daemon-reload
   ```

4. Enable and start the quadlet service:
   ```sh
   sudo systemctl enable <quadlet-service-name>
   sudo systemctl start <quadlet-service-name>
   ```

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

For any questions or suggestions, please open an issue or contact the repository owner.
