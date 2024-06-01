# Add subnet to the VPC
resource "google_compute_network" "malgus_asia_vpc" {
  name                    = "malgus-asia-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  mtu                     = 1460
}

resource "google_compute_subnetwork" "malgus_asia_subnet" {
  name          = var.subnet_asia
  network       = google_compute_network.malgus_asia_vpc.self_link
  ip_cidr_range = var.asia_cidr_range
  region        = var.region_2
}

###################### VM ###############################

# Create compute instance  for asia
resource "google_compute_instance" "asia_instance" {
  name         = "asia-instance"
  machine_type = "e2-medium"  # Adjust machine type as needed
  zone         = "asia-southeast1-b"  # Adjust zone as needed

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2022"  # Windows Server 2019 image
      size  = 50
    }
    auto_delete = true
  }

  network_interface {
    network    = google_compute_network.malgus_asia_vpc.self_link  # Reference the asia VPC
    subnetwork = google_compute_subnetwork.malgus_asia_subnet.self_link  # Reference the asia subnet

    access_config {
      // Ephemeral public IP
    }
  }

  tags = ["http-server"]
}


####################### FIREWALL ############################
# (NOT REQUIRED FOR TESTING PURPOSES ONLY)

# Firewall rules for ICMP (ping) and RDP
resource "google_compute_firewall" "asia_icmp" {
  name        = "asia-icmp"
  network     = google_compute_network.malgus_asia_vpc.self_link
  description = "Allow ICMP (ping) traffic from any source"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "asia_rdp" {
  name        = "asia-rdp"
  network     = google_compute_network.malgus_asia_vpc.self_link
  description = "Allow RDP traffic from any source"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_ranges = ["0.0.0.0/0"]
}



######################gateway#########################################

/*
# Reserve static external IP address for Asia VPN gateway
resource "google_compute_address" "asia_static_ip" {
  name    = "asia-static-ip"
  project = var.project_id
  region  = var.region_2
}
*/






# Gateway (VPN Gateway):
resource "google_compute_vpn_gateway" "asia_vpn_gateway" {
    name        = "asia-vpn-gateway"
    network     = google_compute_network.malgus_asia_vpc.id
    region      = var.region_2
    depends_on  = [google_compute_subnetwork.malgus_asia_subnet]
}


############################ STATIC IP CREATION ##########################################
# Static IP
resource "google_compute_address" "asia_static_ip" {
    name   = "region-2-static-ip"
    region = var.region_2
}



############################ ESP FORWARDING ##########################################
# Forwarding Rule for ESP traffic
resource "google_compute_forwarding_rule" "rule_esp" {
  name        = "rule-esp"
  region      = var.region_2
  ip_protocol = "ESP"
  ip_address  = google_compute_address.asia_static_ip.address
  target      = google_compute_vpn_gateway.asia_vpn_gateway.self_link
  # project = var.project_id
}


############################ UDP FORWARDING 500 ##########################################
# Forwarding Rule for UDP Port 500 traffic
resource "google_compute_forwarding_rule" "rule_udp500" {
  name        = "rule-udp500"
  region      = var.region_2
  ip_protocol = "UDP"
  ip_address  = google_compute_address.asia_static_ip.address
  port_range  = "500"
  target      = google_compute_vpn_gateway.asia_vpn_gateway.self_link
}



############################ UDP FORWARDING 4500 ##########################################
# Forwarding Rule for UDP Port 4500 traffic
resource "google_compute_forwarding_rule" "rule_udp4500" {
  name        = "rule-udp4500"
  region      = var.region_2
  ip_protocol = "UDP"
  ip_address  = google_compute_address.asia_static_ip.address
  port_range  = "4500"
  target      = google_compute_vpn_gateway.asia_vpn_gateway.self_link
}





############################ ASIA TO HQ TUNNEL ##########################################


# Tunnel remote asia to europe hq
resource "google_compute_vpn_tunnel" "asia_to_europe_tunnel" {
  name               = "asia-to-europe-tunnel"
  target_vpn_gateway = google_compute_vpn_gateway.asia_vpn_gateway.self_link
  peer_ip            = google_compute_address.eu_static_ip.address
  shared_secret      = "malgusclan"  # Replace with your shared secret
  ike_version        = 2
  local_traffic_selector  = ["192.168.2.0/24"]  # Replace with Asia VPC subnet
  remote_traffic_selector = ["10.105.10.0/24"]  # Replace with Europe VPC subnet

  depends_on = [
    google_compute_forwarding_rule.rule_esp,
    google_compute_forwarding_rule.rule_udp500,
    google_compute_forwarding_rule.rule_udp4500
  ]
}





############################ FORWARD ICMP ##########################################

# Forwarding Rule for ICMP (Ping) traffic
resource "google_compute_firewall" "allow_icmp" {
  name        = "allow-icmp"
  network     = google_compute_network.malgus_asia_vpc.self_link
  description = "Allow ICMP traffic for network troubleshooting"
  direction   = "INGRESS"
  priority    = 65534
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "icmp"
  }
}


# tunnels





/*
# Create VPN Gateway in Asia VPC
resource "google_compute_vpn_gateway" "asia_vpn_gateway" {
  name    = "asia-vpn-gateway"
  network = google_compute_network.malgus_asia_vpc.self_link
  region  = var.region_2
  project = var.project_id

  # depends_on = [google_compute_address.asia_static_ip]  # Dependency on reserved static IP address
}
*/

############################ INTERNAL FIREWALL##########################################

# route to europe remote
resource "google_compute_route" "route_to_europe" {
  name           = "route-to-europe"
  network        = google_compute_network.malgus_asia_vpc.id
  dest_range     = "10.105.10.0/24"  # Replace with Europe VPC subnet
  priority       = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.asia_to_europe_tunnel.id

  depends_on = [google_compute_vpn_tunnel.asia_to_europe_tunnel]
}

############################ INTERNAL FIREWALL##########################################

# Internal Traffic Firewall Rule
resource "google_compute_firewall" "allow_internal_traffic" {
  name    = "allow-internal-traffic"
  network = google_compute_network.malgus_asia_vpc.id

  allow {
    protocol = "all"
  }

  source_ranges = ["10.105.10.0/24"]  # Replace with Europe VPC subnet
  description   = "Allow all internal traffic from Europe VPC"
}