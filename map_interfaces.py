import yaml
import re
import glob

def get_mapping(conf_file):
    with open(conf_file) as f:
        content = f.read()
    
    # regex to match:
    # source address 2401:1700:1:7::2;
    # ...
    # interface "eth2";
    blocks = re.findall(r'source address ([0-9a-fA-F:]+);.*?interface "(eth\d+)";', content, re.DOTALL)
    
    mapping = {}
    for ip, eth in blocks:
        mapping[ip] = int(eth.replace('eth', ''))
        
    return mapping

with open("/home/well/bird-lab/docker-compose.yml", "r") as f:
    data = yaml.safe_load(f)

for srv_name, srv in data.get("services", {}).items():
    if "networks" not in srv:
        continue
    
    # get ip mapping
    conf_file = f"/home/well/bird-lab/configs/{srv_name}.conf"
    try:
        ip_to_eth = get_mapping(conf_file)
    except Exception as e:
        print(f"Failed to read config for {srv_name}: {e}")
        ip_to_eth = {}
        
    # figure out which docker network gets which eth index
    net_to_eth = {}
    used_eth_indices = set()
    
    for net_name, net_val in srv["networks"].items():
        if net_val and "ipv6_address" in net_val:
            ip = net_val["ipv6_address"]
            if ip in ip_to_eth:
                eth_idx = ip_to_eth[ip]
                net_to_eth[net_name] = eth_idx
                used_eth_indices.add(eth_idx)
                
    # any unassigned networks fill the gaps!
    all_networks = list(srv["networks"].keys())
    unassigned = [n for n in all_networks if n not in net_to_eth]
    
    max_eth = max(used_eth_indices) if used_eth_indices else len(all_networks) - 1
    # total required slots = max_eth + 1. but if len(all_networks) > max_eth + 1, we use more.
    total_slots = max(max_eth + 1, len(all_networks))
    
    eth_gap_idx = 0
    for n in unassigned:
        while eth_gap_idx in used_eth_indices:
            eth_gap_idx += 1
        net_to_eth[n] = eth_gap_idx
        used_eth_indices.add(eth_gap_idx)
        
    # set priorities based on eth index (0 gets 1000, 1 gets 990, etc)
    for net_name, eth_idx in net_to_eth.items():
        if srv["networks"][net_name] is None:
            srv["networks"][net_name] = {}
        srv["networks"][net_name]["priority"] = 1000 - eth_idx * 10
        print(f"{srv_name}: Network {net_name} assigned eth{eth_idx} (Priority: {srv['networks'][net_name]['priority']})")
        
with open("/home/well/bird-lab/docker-compose.yml", "w") as f:
    yaml.dump(data, f, sort_keys=False)
