#!/bin/bash
echo "cloud_io (c) Alex Bokov 2022-2024"

KEY_PATH=/data/ssh_keys
echo "[DEBUG] KEY_PATH=$KEY_PATH"

# Создаём папку для ключей
if [ ! -d "$KEY_PATH" ]; then
    echo "[INFO] Creating directory $KEY_PATH"
    mkdir -p "$KEY_PATH"
    if [ $? -ne 0 ]; then
        echo "[ERROR] Failed to create $KEY_PATH"
        exit 1
    fi
    echo "[INFO] Directory created"
else
    echo "[INFO] Directory $KEY_PATH already exists"
fi

# Проверяем наличие ключа
if [ ! -f "${KEY_PATH}/autossh_ed25519" ]; then
    echo "[INFO] Private key not found, generating new key..."
    ssh-keygen -t ed25519 -N "" -f "${KEY_PATH}/autossh_ed25519" 2>&1
    if [ $? -ne 0 ]; then
        echo "[ERROR] Failed to generate SSH key"
        exit 1
    fi
    echo "[INFO] Key generated successfully"
else
    echo "[INFO] Private key already exists, restoring..."
fi

# Выводим публичный ключ
if [ -f "${KEY_PATH}/autossh_ed25519.pub" ]; then
    echo "[INFO] Public key:"
    cat "${KEY_PATH}/autossh_ed25519.pub"
else
    echo "[ERROR] Public key file not found!"
    exit 1
fi

# Проверяем права
echo "[INFO] Key files:"
ls -la "$KEY_PATH"

echo "[INFO] json config is:"
cat /data/options.json

client_id=$(jq -r ".client_id" /data/options.json)
client_ssh=$(jq -r ".client_ssh" /data/options.json)
router_webui=$(jq -r ".router_webui" /data/options.json)

curl -s -X GET -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" http://supervisor/network/info > /tmp/networkinfo
hassio_ip=$(jq -r ".data.interfaces[] | .ipv4.address[]" /tmp/networkinfo | awk -F/ '{print $1}')
router_ip=$(jq -r ".data.interfaces[] | .ipv4.gateway | select( . != null )" /tmp/networkinfo)

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

    if [ "$client_ssh" = "true" ]; then
        ssh_control_port=$((client_id+2))
        ssh_monitor_port=$((control_port+3))
        command_args="-M ${ssh_monitor_port} -R 0.0.0.0:${ssh_control_port}:${hassio_ip}:22 -N -q -o ServerAliveInterval=5 -o ServerAliveCountMax=1 ${cloud_username}@${cloud_hostname} -p ${cloud_ssh_port} -i ${KEY_PATH}/autossh_ed25519"
        echo "[INFO] command args: ${command_args}"
        /usr/bin/autossh ${command_args} &
    fi

    if [ "$router_webui" = "true" ]; then
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
