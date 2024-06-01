# VPC and Subnetwork for Americas Headquarters
resource "google_compute_network" "malgus_americas_vpc" {
  name                    = "malgus-americas-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  mtu                     = 1460
}

# First subnet for the Americas Network
resource "google_compute_subnetwork" "malgus_americas_subnet" {
  name          = var.subnet_1
  ip_cidr_range = var.ip_cidr_range2
  region        = var.region1
  network       = google_compute_network.malgus_americas_vpc.self_link
}

# Second subnet for the Americas Network
resource "google_compute_subnetwork" "malgus_americas_subnet2" {
  name          = var.subnet_2
  ip_cidr_range = var.ip_cidr_range3
  region        = var.region2
  network       = google_compute_network.malgus_americas_vpc.self_link
}

# Firewall Rule to Allow SSH Traffic in Americas
resource "google_compute_firewall" "allow_ssh" {
  project      = var.project_id
  name         = "allow-ssh"
  network      = google_compute_network.malgus_americas_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_tags   = ["ssh"] 
  source_ranges = ["0.0.0.0/0"]  # Allow SSH access from any IP address
}

# Firewall Rule to Allow Port 80 Traffic in Americas
resource "google_compute_firewall" "allow_port_80_americas" {
  project      = var.project_id
  name         = "allow-port-80-americas"
  network      = google_compute_network.malgus_americas_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
}

# Global Address for Remote to HQ VPC Peering
resource "google_compute_global_address" "remote_to_hq_vpc_global_address" {
  name          = var.remote-to-hq-address-1
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.malgus_americas_vpc.id
}

# Network Peering: HQ to Remote
resource "google_compute_network_peering" "hq_to_remote_peer" {
  name         = var.hq_to_remote_peer
  network      = google_compute_network.hq_vpc.self_link
  peer_network = google_compute_network.malgus_americas_vpc.self_link
}

# Compute Instance 1 in Americas VPC
resource "google_compute_instance" "americas_instance_1" {
  name         = "americas-instance-1"
  machine_type = "e2-micro"
  zone         = "us-east1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
    auto_delete = true
  }

  network_interface {
    network    = google_compute_network.malgus_americas_vpc.self_link
    subnetwork = google_compute_subnetwork.malgus_americas_subnet.self_link
  
  access_config {
      // Ephemeral public IP
    }
  
  }

  tags = ["http-server"]
}

# Compute Instance 2 in Americas VPC
resource "google_compute_instance" "americas_instance_2" {
  name         = "americas-instance-2"
  machine_type = "e2-micro"
  zone         = "us-central1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
    auto_delete = true
  }

  network_interface {
    network    = google_compute_network.malgus_americas_vpc.self_link
    subnetwork = google_compute_subnetwork.malgus_americas_subnet2.self_link
  
 access_config {
      // Ephemeral public IP
    }

  }

  tags = ["http-server"]
}
