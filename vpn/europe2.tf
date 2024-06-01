# VPC and Subnetwork for Europe Headquarters
resource "google_compute_network" "hq_vpc" {
  name                    = "malgus-eu-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  mtu                     = 1460
}

resource "google_compute_subnetwork" "hq_subnet" {
  name          = var.subnet_hq
  network       = google_compute_network.hq_vpc.self_link
  ip_cidr_range = var.hq_cidr_range
  region        = var.hq_region
}

/*
# Firewall Rule to Allow Port 80 Traffic in Europe
resource "google_compute_firewall" "allow_port_80_eu" {
  project = var.project_id
  name    = "allow-port-80-eu"
  network = google_compute_network.hq_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
}


# Global Address for HQ to Remote VPC Peering
resource "google_compute_global_address" "hq_to_remote_vpc_global_address" {
  name          = var.hq-to-remote-address
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.hq_vpc.id
}

# Network Peering: Remote to HQ
resource "google_compute_network_peering" "remote_to_hq_peer" {
  name         = var.remote_to_hq_peer
  network      = google_compute_network.malgus_americas_vpc.self_link
  peer_network = google_compute_network.hq_vpc.self_link
}

# Auto-created Network for Europe Peering
resource "google_compute_network" "eu_peer1_vpcn_network" {
  name                    = "europe-peering-net"
  auto_create_subnetworks = "true"
}

# Auto-created Network for Americas Peering
resource "google_compute_network" "americas_peer1_vpc_network" {
  name                    = "americas-peering-net"
  auto_create_subnetworks = "true"
}
*/
###################### VM ###############################

# Instance in Europe HQ VPC
resource "google_compute_instance" "hq_instance" {
  name         = "europe-instance"
  machine_type = "n1-standard-1"
  zone         = "europe-west1-b"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = 10
    }
    auto_delete = true
  }

  network_interface {
    network    = google_compute_network.hq_vpc.self_link
    subnetwork = google_compute_subnetwork.hq_subnet.self_link


access_config {
      // Ephemeral public IP
    }

}
  tags = ["http-server"]

  metadata_startup_script = "${file("${path.module}/startup.sh")}"
}
############################RDP##########################################

resource "google_compute_firewall" "europe_rdp" {
  name        = "europe-rdp"
  network     = google_compute_network.hq_vpc.self_link
  description = "Allow RDP traffic from any source"
  #direction   = "INGRESS"
  #priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_ranges = ["0.0.0.0/0"] # add asia's ip range
  
  target_tags = ["rdp-enabled"]
}

############################ICMP FORWARDING##########################################


# Forwarding Rule for ICMP (Ping) traffic
resource "google_compute_firewall" "allow_icmp_europe" {
  name        = "allow-icmp-europe"
  network     = google_compute_network.malgus_asia_vpc.self_link
  description = "Allow ICMP traffic for network troubleshooting"
  direction   = "INGRESS"
  priority    = 65534
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "icmp"
  }
}



############################VPN GATEWAY##########################################

# Gateway (VPN Gateway):
resource "google_compute_vpn_gateway" "europe_vpn_gateway" {
    name        = "europe-vpn-gateway"
    network     = google_compute_network.hq_vpc.id
    region      = var.hq_region
    depends_on  = [google_compute_subnetwork.hq_subnet]
}

############################STATIC IP##########################################

# IP Birth (Reserved Static IP Address):
resource "google_compute_address" "eu_static_ip" {
    name   = "region-1-static-ip"
    region = var.hq_region
}


############################ESP FORWARDING##########################################


# Forwarding Rule for ESP traffic
resource "google_compute_forwarding_rule" "rule_esp_fw" {
  name        = "rule-esp-europe"
  region      = var.hq_region
  ip_protocol = "ESP"
  ip_address  = google_compute_address.eu_static_ip.address
  target      = google_compute_vpn_gateway.europe_vpn_gateway.self_link
}


############################UDP500##########################################


# Forwarding Rule for UDP Port 500 traffic
resource "google_compute_forwarding_rule" "rule_udp_500" {
  name        = "rule-udp500-europe"
  region      = var.hq_region
  ip_protocol = "UDP"
  ip_address  = google_compute_address.eu_static_ip.address
  port_range  = "500"
  target      = google_compute_vpn_gateway.europe_vpn_gateway.self_link
}

############################UDP4500##########################################


# Forwarding Rule for UDP Port 4500 traffic
resource "google_compute_forwarding_rule" "rule_udp_4500" {
  name        = "rule-udp4500-europe"
  region      = var.hq_region
  ip_protocol = "UDP"
  ip_address  = google_compute_address.eu_static_ip.address
  port_range  = "4500"
  target      = google_compute_vpn_gateway.europe_vpn_gateway.self_link
}



############################SSH##########################################
#(NOT REQUIRED USED OFR TESTING ONLY)

# AlloW SSH
resource "google_compute_firewall" "allow_ssh_europe" {
  name        = "allow-ssh-europe"
  network     = google_compute_network.hq_vpc.self_link
  description = "Allow ICMP traffic for network troubleshooting"
  direction   = "INGRESS"
  
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
}

############################EUROPE TUNNEL##########################################
# Tunnel from Europe to Asia
resource "google_compute_vpn_tunnel" "europe_to_asia_tunnel" {
  name               = "europe-to-asia-tunnel"
  target_vpn_gateway = google_compute_vpn_gateway.europe_vpn_gateway.self_link
  peer_ip            = google_compute_address.asia_static_ip.address
  shared_secret      = "malgusclan"  # Replace with your shared secret
  ike_version        = 2
  local_traffic_selector  = ["10.105.10.0/24"]  # Replace with Europe VPC subnet
  remote_traffic_selector = ["192.168.2.0/24"]    # Replace with Asia VPC subnet

  depends_on = [
    google_compute_forwarding_rule.rule_esp_fw,
    google_compute_forwarding_rule.rule_udp_500,
    google_compute_forwarding_rule.rule_udp_4500
  ]
}
############################ROUTE##########################################
# Next Hop to Final Destination in Asia
resource "google_compute_route" "route_to_asia" {
  name           = "route-to-asia"
  network        = google_compute_network.hq_vpc.id
  dest_range     = "192.168.2.0/24"  # Replace with Asia VPC subnet
  priority       = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.europe_to_asia_tunnel.id

  depends_on = [google_compute_vpn_tunnel.europe_to_asia_tunnel]
}

############################INTERNAL##########################################
# Internal Traffic Firewall Rule for Europe
resource "google_compute_firewall" "allow_internal_traffic_europe" {
  name    = "allow-internal-traffic-europe"
  network = google_compute_network.hq_vpc.id

  allow {
    protocol = "all"
  }

  source_ranges = ["192.168.2.0/24"]  # Replace with Asia VPC subnet
  description   = "Allow all internal traffic from Asia VPC"
}
