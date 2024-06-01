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
