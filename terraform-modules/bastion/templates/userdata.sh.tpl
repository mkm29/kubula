#!/bin/bash
set -ex

# Update system
yum update -y

# Install essential tools
yum install -y \
  aws-cli \
  jq \
  git \
  vim \
  htop \
  nc \
  telnet

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

%{ if enable_session_manager }
# Configure SSM Session Manager
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
%{ endif }

%{ if enable_cloudwatch_logs }
# Configure CloudWatch logs
yum install -y awslogs

cat > /etc/awslogs/awslogs.conf <<EOF
[general]
state_file = /var/lib/awslogs/agent-state

[/var/log/secure]
datetime_format = %b %d %H:%M:%S
file = /var/log/secure
buffer_duration = 5000
log_stream_name = {instance_id}/var/log/secure
initial_position = start_of_file
log_group_name = ${cloudwatch_log_group}

[/var/log/messages]
datetime_format = %b %d %H:%M:%S
file = /var/log/messages
buffer_duration = 5000
log_stream_name = {instance_id}/var/log/messages
initial_position = start_of_file
log_group_name = ${cloudwatch_log_group}
EOF

sed -i "s/region = us-east-1/region = ${region}/g" /etc/awslogs/awscli.conf

systemctl enable awslogsd
systemctl start awslogsd
%{ endif }

%{ if enable_eip }
# Associate Elastic IP
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
ALLOCATION_ID=$(aws ec2 describe-addresses --region ${region} --filters "Name=tag:Name,Values=*bastion-eip*" --query 'Addresses[?AssociationId==null].AllocationId' --output text | awk '{print $1}')

if [ ! -z "$ALLOCATION_ID" ]; then
  aws ec2 associate-address --region ${region} --instance-id $INSTANCE_ID --allocation-id $ALLOCATION_ID
fi
%{ endif }

# Configure SSH hardening
cat >> /etc/ssh/sshd_config <<EOF

# Security hardening
PermitRootLogin no
PasswordAuthentication no
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

systemctl restart sshd

# Configure shell timeout
echo "TMOUT=900" >> /etc/profile.d/timeout.sh
chmod +x /etc/profile.d/timeout.sh

# Custom user data
${custom_user_data}