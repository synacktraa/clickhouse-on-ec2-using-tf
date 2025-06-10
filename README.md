# Clickhouse on EC2 using terraform

## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform installed**

## Deployment Steps

### 1. Initialize Terraform

```bash
git clone https://github.com/synacktraa/clickhouse-on-ec2-using-tf.git
cd clickhouse-on-ec2-using-tf
terraform init
```

### 2. Create Keys

```bash
ssh-keygen -t rsa -b 4096 -f ec2-clickhouse
```

### 3. Apply the Configuration

```bash
terraform apply
```

#### Variables

- `instance_type` - Change Instance's type (Default: `t3.small`)
- `volume_size` - Modify storage size of the device (Default: `20gb`)
- `allowed_cidr_blocks` - Restrict access to certain IPs (Default: `0.0.0.0/0`)

Type `yes` when prompted to confirm the deployment.

### 4. Get Outputs

After deployment, get the connection details:

```bash
# Get public IP and connection info
terraform output

# Get the generated password of clickhouse server (sensitive output)
terraform output -raw clickhouse_password
```

## Accessing the instance

### Via SSH Tunnel

```bash
$(terraform output -raw ssh_command)
```

### Clickhouse HTTP Interface (Web/API)

```bash
# Basic health check
curl http://$(terraform output -raw public_ip):8123/ping

# Run a simple query
curl -u "default:$(terraform output -raw clickhouse_password)" "http://$(terraform output -raw public_ip):8123/?query=SELECT+version()"
```

### Clickhouse Native TCP Client

```bash
clickhouse-client --host $(terraform output -raw public_ip) --port 9000 --user default --password $(terraform output -raw clickhouse_password)
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` when prompted to confirm destruction.

## Troubleshooting

1. Verify security group rules allow your IP
2. Check if ClickHouse is listening: `netstat -tlnp | grep :8123`
3. Test from within the instance: `curl localhost:8123/ping`
