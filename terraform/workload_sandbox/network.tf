# Vlastní, izolovaná VPC pro honeypot — místo spoléhání na default VPC
# účtu. Důvod: honeypot je záměrně vystavený internetu a chceme, aby
# jeho síťové prostředí bylo oddělené od čehokoliv jiného, co by v tomto
# účtu mohlo v budoucnu běžet (viz ADR-005).

resource "aws_vpc" "honeypot" {
  cidr_block           = "10.42.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "vl-honeypot-vpc"
    Purpose = "honeypot"
    Owner   = var.owner_tag
  }
}

# Veřejný subnet — honeypot MUSÍ být veřejně dostupný, to je celý smysl
# (viz README: cílem je nechat boty najít otevřený port). "Veřejný"
# zde znamená: má route do Internet Gateway, ne že by šlo o
# bezpečnostní nedbalost.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.honeypot.id
  cidr_block              = "10.42.0.0/28"
  map_public_ip_on_launch = true

  tags = {
    Name    = "vl-honeypot-public-subnet"
    Purpose = "honeypot"
    Owner   = var.owner_tag
  }
}

resource "aws_internet_gateway" "honeypot" {
  vpc_id = aws_vpc.honeypot.id

  tags = {
    Name    = "vl-honeypot-igw"
    Purpose = "honeypot"
    Owner   = var.owner_tag
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.honeypot.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.honeypot.id
  }

  tags = {
    Name    = "vl-honeypot-public-rt"
    Purpose = "honeypot"
    Owner   = var.owner_tag
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
