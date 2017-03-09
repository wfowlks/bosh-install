resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

resource "aws_subnet" "public" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.public_subnet_cidr}"
  availability_zone = "${var.default_az}"
  map_public_ip_on_launch = true
  depends_on = ["aws_internet_gateway.default"]
  tags {
    Name = "bosh-inception"
  }
}

resource "aws_subnet" "bosh_director" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.bosh_subnet_cidr}"
  availability_zone = "${var.default_az}"
  map_public_ip_on_launch = false
  tags {
    Name = "bosh-director"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "bosh" {
  subnet_id = "${aws_subnet.bosh_director.id}"
  route_table_id = "${aws_route_table.public.id}"
}