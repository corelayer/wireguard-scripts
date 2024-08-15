# wireguard-scripts

## Server
### Create server
```create_server.sh``` will create a Wireguard server using the parameters provided below.

The IP address of the wireguard interface will always be the first address in the ```/24``` network provided through the ```Server Network``` parameter.

For example, if the server network parameter is set to ```192.168.100```, the address for the wireguard interface will be ```192.168.100.1/24```.

#### Parameters

| Position | Parameter | Description | Example |
| --- | --- | --- | --- |
| 1 | Public Address | Public Address the server is available at, can be a FQDN | vip.domain.com / 169.254.0.0 |
| 2 | Public Port | Port on which the server is available | 51820 |
| 3 | Interface Name | Network interface on the host through which traffic will be routed | eth0 |
| 4 | Server Name | Wireguard interface name | wg0 |
| 5 | Server Network | Wireguard network prefix | 192.168.100 |
| 6 | Enable NAT | Configure NAT for wireguard trafic | 0 \| 1 |

##### Example 1
```sh create_server.sh vip.domain.com 51820 eth0 wg0 192.168.100 1 0```

This will create a wireguard server ```wg0``` with address ```192.168.100.1```, routing traffic through ```eth0```. Traffic to other networks on eth0 will have a source address of ```192.168.100.1``` using NAT.

Clients added using the ```create_client.sh``` scripts will connect to ```vip.domain.com:51820```

##### Example 2
```sh create_server.sh vip.domain.com 51820 eth0 wg0 192.168.100 1 1```

This will create a wireguard server ```wg0``` with address ```192.168.100.1```, routing traffic through ```eth0```. Traffic to other networks on eth0 will have a source address corresponding to the client IP address on the ```wg0``` interface, e.g. source ip address ```192.168.100.2```, and will not be hidden behind NAT.

Clients added using the ```create_client.sh``` scripts will connect to ```vip.domain.com:51820```

#### Output

The script will create 4 files in the directory:
- ```server.key```: the private key for the server
- ```server.pub```: the public key for the server
- ```server.var``` will store all the configured parameters.
- ```server.conf``` will store the template server configuration.


### Create client

```create_client.sh``` will create a Wireguard client using the parameters provided below.

The IP address of the wireguard client will be the same as the client ID provided in the parameters, and must be between 2 and 254.
For example, if the server network parameter is set to ```192.168.100```, and the client id is set to ```2```, the address for the wireguard client will be ```192.168.100.2/24```.

#### Parameters

| Position | Parameter | Description | Example |
| --- | --- | --- | --- |
| 1 | Client ID | Numeric ID of the client, corresponds with the IP Address that will be used | 2-254 |
| 2 | Client Name | Name for the client | corelayer |
| 3 | Client Location | Location of the client | laptop |
| 4 | Reload Server | Reload the server configuration to accept connections from the new client | 1 |

The client name and location are simple identifiers so you can easily distinguish different clients.

##### Example
```sh create_client.sh 2 corelayer laptop 1```

This command will create a wireguard client to connect to the public address/port defined for the wireguard server. The client will get IP address 2 on the wireguard network. For easy management, the client will have a name ```002_corelayer_laptop``` for the wireguard peer. Finally the server configuration will be reloaded.

#### Output

The script will create 3 files:
- ```<client_id>_<customer_name>_<customer_location>.key```: the private key for the client
- ```<client_id>_<customer_name>_<customer_location>.pub```: the public key for the client
- ```<client_id>_<customer_name>_<customer_location>.conf```: the wireguard client configuration to be exported to the client

When the server configuration is reloaded using ```reload_server.sh```, the client will be added to the server configuration.


### Reload server

This script will recreate the configuration of the server using ```server.var``` and ```server.conf```, and then add all the configured clients to the configuration ordered by client id.

As as last step, it will reload the configuration using ```systemctl reload wg-quick@<server name>```, e.g. ```systemctl reload wg-quick@wg0```.

#### Example
```sh reload_server.sh```

## Client
To configure the client, import the client configuration into the wireguard application.

### Routing
#### Wireguard server *without* NAT
As an example, we have a wireguard server with the following configuration:
- Host network: 172.16.1.1/24
- Host interface: eth0
- Wireguard server interface: wg0
- Wireguard server address: 192.168.100.1
- NAT **disabled**

##### Client configuration
- You need to add the server networks you want to reach from the client in the ```AllowedIPs=``` section as a comma-separated list.
- You will also need to add a route on the client that will send traffic through the wireguard tunnel for the destination networks, e.g.:<br>
```ip route add 172.16.0.0/16 via 192.168.100.1 dev wg0```

##### Server-side configuration
- You need to add the wireguard network route for 192.168.100.0/24 on your firewall/router via 172.16.1.1
- Firewall rules will need to accept traffic from IP addresses in 192.168.100.0/24 (or more specific addresses of wireguard clients)

#### Wireguard server *with* NAT
As an example, we have a wireguard server with the following configuration:
- Host network: 172.16.1.1/24
- Host interface: eth0
- Wireguard server interface: wg0
- Wireguard server address: 192.168.100.1
- NAT **enabled**

##### Client configuration
- You need to add the server networks you want to reach from the client in the ```AllowedIPs=``` section as a comma-separated list.
- You will also need to add a route on the client that will send traffic through the wireguard tunnel for the destination networks, e.g.:<br>
```ip route add 172.16.0.0/16 via 192.168.100.1 dev wg0```

##### Server-side configuration
- All traffic from the wireguard clients to a server-side network will be behind NAT using 172.16.1.1 as the source IP address.


### Linux
#### Configuration
- Go to ```/etc/wireguard```
- Create/Open ```wg0.conf``` for editing
- Copy the contents of your client configuration into the file and save.
- Start/Reload the systemd service for your connection: ```systemctl restart wg-quick@wg0``` / ```systemctl reload wg-quick@wg0```

#### Watchdog
Execute the following commands as ```root```:
- Copy ```watchdog.sh``` script in ```/etc/wireguard/watchdog.sh```
- Set the owner for the script: ```chown root:root /etc/wireguard/watchdog.sh```
- Set the permissions for the script: ```chmod 600 /etc/wireguard/watchdog.sh```
- Edit the crontab file for root: ```crontab -e```
- Add the following line and save: ```* * * * * sh /etc/wireguard/watchdog.sh | logger -t wireguard-watchdog 2>&1```

You can find the logs in syslog.