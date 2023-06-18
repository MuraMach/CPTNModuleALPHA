#!/bin/bash

# Check if the script is running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo."
    exit 1
fi

# Cockpit API endpoint
cockpit_host="localhost"
cockpit_port="9090"

# Container names
container_names=("node1" "node2" "node3")

# Function to fetch container information using Cockpit API
get_container_info() {
    local container_name=$1
    local cockpit_host=$2
    local cockpit_port=$3

    curl -sS -k -u "<cockpit_username>:<cockpit_password>" "https://$cockpit_host:$cockpit_port/api/system/containers/$container_name"
}

# Function to fetch pose score using neoxa-cli
get_pose_score() {
    local container_id=$1

    pose_score=$(podman exec "$container_id" /app/neoxa-cli -datadir=/var/lib/neoxa smartnode status | awk '/^POSESCORE:/ {print $2}')
    echo "${pose_score:-N/A}"
}

# Function to generate the HTML page with container information
generate_html_page() {
    local container_info=$1
    local output_file=$2

    echo "<!DOCTYPE html>
<html>
<head>
  <title>Container Status</title>
  <style>
    .container {
      border: 1px solid #ccc;
      border-radius: 5px;
      margin-bottom: 10px;
      padding: 10px;
    }

    .container-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .container-name {
      font-weight: bold;
    }

    .container-status {
      margin-left: 10px;
      padding: 5px 10px;
      border-radius: 5px;
      font-weight: bold;
    }

    .container-info {
      margin-top: 10px;
      white-space: pre-wrap;
      background-color: #f5f5f5;
      padding: 10px;
      border-radius: 5px;
    }
  </style>
</head>
<body>
  <h1>Container Status</h1>" > "$output_file"

    while IFS=: read -r CONTAINER_ID CONTAINER_NAME; do
        echo "<div class=\"container\" id=\"$CONTAINER_NAME\">
    <div class=\"container-header\">
      <h2 class=\"container-name\">$CONTAINER_NAME</h2>
      <span class=\"container-status\" id=\"$CONTAINER_NAME-status\">Loading...</span>
    </div>
    <div class=\"container-info\" id=\"$CONTAINER_NAME-info\"></div>
  </div>" >> "$output_file"
    done <<< "$container_info"

    echo "
  <script>
    function fetchContainerInfo(containerName) {
      fetch(\`/api/containers/\${containerName}\`)
        .then(response => response.json())
        .then(data => {
          const containerStatusElement = document.getElementById(\`${containerName}-status\`);
          const containerInfoElement = document.getElementById(\`${containerName}-info\`);

          containerStatusElement.textContent = data.status || 'Unknown';
          containerInfoElement.textContent = JSON.stringify(data, null, 2);
        })
        .catch(error => {
          console.error(\`Failed to fetch container info for \${containerName}:\`, error);
          const containerStatusElement = document.getElementById(\`${containerName}-status\`);
          containerStatusElement.textContent = 'Error';
        });
    }

    function fetchPoseScore(containerName) {
      fetch(\`/api/containers/\${containerName}/posescore\`)
        .then(response => response.text())
        .then(data => {
          const poseScoreElement = document.getElementById(\`${containerName}-posescore\`);
          poseScoreElement.textContent = data || 'N/A';
        })
        .catch(error => {
          console.error(\`Failed to fetch pose score for \${containerName}:\`, error);
          const poseScoreElement = document.getElementById(\`${containerName}-posescore\`);
          poseScoreElement.textContent = 'Error';
        });
    }

    function fetchAllContainerInfo() {
      const containerNames = [$(printf "\"%s\"," "${container_names[@]}")];
      containerNames.forEach(containerName => {
        fetchContainerInfo(containerName);
        fetchPoseScore(containerName);
      });
    }

    // Fetch container info and pose score on page load
    fetchAllContainerInfo();

    // Refresh container info and pose score every 5 minutes
    setInterval(fetchAllContainerInfo, 300000);
  </script>
</body>
</html>" >> "$output_file"
}
