#!/usr/bin/env bash
#
# Keystone Datas
#
# Description: Fill Keystone with datas.

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

source $TOP_DIR/openstackrc

ADMIN_PASSWORD=$PASSWORD
SERVICE_PASSWORD=${SERVICE_PASSWORD:-$ADMIN_PASSWORD}
SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}

# MySQL definitions
MYSQL_USER=keystone
MYSQL_DATABASE=keystone
MYSQL_HOST=localhost
MYSQL_PASSWORD=$PASSWORD

# Keystone definitions
KEYSTONE_REGION=RegionOne
SERVICE_TOKEN=$TOKEN
SERVICE_ENDPOINT="http://localhost:35357/v2.0"

# other definitions
SERVICE_URL=$HOST_IP

get_field() {
    while read data; do
        if [ "$1" -lt 0 ]; then
            field="(\$(NF$1))"
        else
            field="\$$(($1 + 1))"
        fi
        echo "$data" | awk -F'[ \t]*\\|[ \t]*' "{print $field}"
    done
}

get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

# Tenants
ADMIN_TENANT=$(get_id keystone tenant-create --name=admin)
SERVICE_TENANT=$(get_id keystone tenant-create --name=$SERVICE_TENANT_NAME)
DEMO_TENANT=$(get_id keystone tenant-create --name=demo)
INVIS_TENANT=$(get_id keystone tenant-create --name=invisible_to_admin)

# Users
ADMIN_USER=$(get_id keystone user-create --name=admin --pass="$ADMIN_PASSWORD" --email=admin@domain.com)
DEMO_USER=$(get_id keystone user-create --name=demo --pass="$ADMIN_PASSWORD" --email=demo@domain.com)

# Roles
ADMIN_ROLE=$(get_id keystone role-create --name=admin)
KEYSTONEADMIN_ROLE=$(get_id keystone role-create --name=KeystoneAdmin)
KEYSTONESERVICE_ROLE=$(get_id keystone role-create --name=KeystoneServiceAdmin)

# Add Roles to Users in Tenants
keystone user-role-add --user-id $ADMIN_USER --role-id $ADMIN_ROLE --tenant-id $ADMIN_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $ADMIN_ROLE --tenant-id $DEMO_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $KEYSTONEADMIN_ROLE --tenant-id $ADMIN_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $KEYSTONESERVICE_ROLE --tenant-id $ADMIN_TENANT

# The Member role is used by Horizon and Swift
MEMBER_ROLE=$(get_id keystone role-create --name=Member)
keystone user-role-add --user-id $DEMO_USER --role-id $MEMBER_ROLE --tenant-id $DEMO_TENANT
keystone user-role-add --user-id $DEMO_USER --role-id $MEMBER_ROLE --tenant-id $INVIS_TENANT

# Configure service users/roles
NOVA_USER=$(get_id keystone user-create --name=nova --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=nova@domain.com)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $NOVA_USER --role-id $ADMIN_ROLE

GLANCE_USER=$(get_id keystone user-create --name=glance --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=glance@domain.com)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $GLANCE_USER --role-id $ADMIN_ROLE

SWIFT_USER=$(get_id keystone user-create --name=swift --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=swift@domain.com)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $SWIFT_USER --role-id $ADMIN_ROLE

RESELLER_ROLE=$(get_id keystone role-create --name=ResellerAdmin)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $NOVA_USER --role-id $RESELLER_ROLE

CINDER_USER=$(get_id keystone user-create --name=cinder --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=cinder@domain.com)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $CINDER_USER --role-id $ADMIN_ROLE

# Services
NOVA_SERVICE=$(keystone service-create --name nova --type compute --description "OpenStack Compute Service" | grep " id " | get_field 2)
GLANCE_SERVICE=$(keystone service-create --name glance --type image --description "OpenStack Image Service" | grep " id " | get_field 2)
CINDER_SERVICE=$(keystone service-create --name cinder --type volume --description "OpenStack Volume Service" | grep " id " | get_field 2)
KEYSTONE_SERVICE=$(keystone service-create --name keystone --type identity --description "OpenStack Identity Service" | grep " id " | get_field 2)
EC2_SERVICE=$(keystone service-create --name ec2 --type ec2 --description "EC2 Service" | grep " id " | get_field 2)


# End Point Create
## nova-api
keystone endpoint-create --region $KEYSTONE_REGION --service_id $NOVA_SERVICE \
                                           --publicurl "http://$SERVICE_URL:8774/v2/%(tenant_id)s" \
                                           --adminurl "http://$SERVICE_URL:8774/v2/%(tenant_id)s" \
                                           --internalurl "http://$SERVICE_URL:8774/v2/%(tenant_id)s"
## glance 
keystone endpoint-create --region $KEYSTONE_REGION --service_id $GLANCE_SERVICE \
                                           --publicurl "http://$SERVICE_URL:9292/v1" \
                                           --adminurl "http://$SERVICE_URL:9292/v1" \
                                           --internalurl "http://$SERVICE_URL:9292/v1"

## keystone
keystone endpoint-create --region $KEYSTONE_REGION --service_id $KEYSTONE_SERVICE \
                                           --publicurl "http://$SERVICE_URL:5000/v2.0" \
                                           --adminurl "http://$SERVICE_URL:35357/v2.0" \
                                           --internalurl "http://$SERVICE_URL:5000/v2.0"

## EC2
keystone endpoint-create --region $KEYSTONE_REGION --service_id $EC2_SERVICE \
                                           --publicurl "http://$SERVICE_URL:8773/services/Cloud" \
                                           --adminurl "http://$SERVICE_URL:8773/services/Admin" \
                                           --internalurl "http://$SERVICE_URL:8773/services/Cloud"

## Cinder
keystone endpoint-create --region $KEYSTONE_REGION --service_id $CINDER_SERVICE \
                                           --publicurl "http://$SERVICE_URL:8776/v1/%(tenant_id)s" \
                                           --adminurl "http://$SERVICE_URL:8776/v1/%(tenant_id)s" \
                                           --internalurl "http://$SERVICE_URL:8776/v1/%(tenant_id)s"
