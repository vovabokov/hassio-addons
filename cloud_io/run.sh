#!/usr/bin/with-contenv bashio

echo "cloud_io (c) Alex Bokov 2022-2024"

# Generate key
KEY_PATH=/data/ssh_keys
if [ ! -d "$KEY_PATH" ]; then
    echo "[INFO] Setup private key"
    mkdir -p "$KEY_PATH"
    ssh-keygen -t ed25519 -N "" -f "${KEY_PATH}/autossh_ed25519"
else
    echo "[INFO] Restore private_keys"
fi

echo "[INFO] public key is:"
cat "${KEY_PATH}/autossh_ed25519.pub"

echo "[INFO] json config is:"
cat /data/options.json 

client_id=$(bashio::config 'client_id')
client_ssh=$(bashio::config 'client_ssh')
router_webui=$(bashio::config 'router_webui')

# Get network info using bashio
hassio_ip=$(bashio::network.ipv4_address)
router_ip=$(bashio::network.gateway)

cloud_hostname='cloud.uzvhost.ru'
cloud_username='cloudio'
cloud_ssh_port=722
control_port=$((client_id))
monitor_port=$((control_port+1))

while true
do
    echo "loop start..."
    echo "[INFO] testing cloud ssh connection"
    ssh -o StrictHostKeyChecking=no -p $cloud_ssh_port $cloud_hostname 2>/dev/null || true

    if [ "$client_ssh" = true ]; then
        ssh_control_port=$((client_id+2))
        ssh_monitor_port=$((control_port+3))
        command_args="-M ${ssh_monitor_port} -R 0.0.0.0:${ssh_control_port}:${hassio_ip}:22 -N -q -o ServerAliveInterval=5 -o ServerAliveCountMax=1 ${cloud_username}@${cloud_hostname} -p ${cloud_ssh_port} -i ${KEY_PATH}/autossh_ed25519"
        echo "[INFO] command args: ${command_args}"
        /usr/bin/autossh ${command_args} &
    fi

    if [ "$router_webui" = true ]; then
        router_webui_control_port=$((client_id+4))
        router_webui_monitor_port=$((control_port+5))
        command_args="-M ${router_webui_monitor_port} -R 0.0.0.0:${router_webui_control_port}:${router_ip}:80 -N -q -o ServerAliveInterval=5 -o ServerAliveCountMax=1 ${cloud_username}@${cloud_hostname} -p ${cloud_ssh_port} -i ${KEY_PATH}/autossh_ed25519"
        echo "[INFO] command args: ${command_args}"
        /usr/bin/autossh ${command_args} &
    fi

    command_args="-M ${monitor_port} -R 0.0.0.0:${control_port}:${hassio_ip}:8123 -N -q -o ServerAliveInterval=5 -o ServerAliveCountMax=1 ${cloud_username}@${cloud_hostname} -p ${cloud_ssh_port} -i ${KEY_PATH}/autossh_ed25519"
    echo "[INFO] command args: ${command_args}"
    /usr/bin/autossh ${command_args} || true
    
    echo "repeating in 60 sec..."
    sleep 60
done