export NAMESPACE=km

#gcloud auth login
export GOOGLE_PROJECT_ID=`gcloud config get-value core/project`
export GOOGLE_PROJECT_NUMBER=`gcloud projects describe $GOOGLE_PROJECT_ID --format="value(projectNumber)"`
export BUCKET_SRC=$GOOGLE_PROJECT_ID-squid-conf-$NAMESPACE
export REGION=us-central1
export ZONE=us-central1-a
export SVC_ACCT=squid-svc-account-$NAMESPACE
export GCE_SERVICE_ACCOUNT=$SVC_ACCT\@$GOOGLE_PROJECT_ID.iam.gserviceaccount.com
export STARTUP_SCRIPT=startupsquid.sh
export NETNAME=custom-network-$NAMESPACE
export SECRET_NAME=squidkey-$NAMESPACE
export RANGE=192.168.1.0/24
export PREFIX=`echo $RANGE|cut -c1-3`
export SUBNET=$NETNAME-subnet-$REGION\-$PREFIX
export NAT_ROUTER=squid-nat-router-$NAMESPACE
export NAT_IP=squid-natip-$NAMESPACE
export NAT_CONF=squid-nat-config-$NAMESPACE
export TEMPLATE_NAME=squid-template-$NAMESPACE
export PROXY_TAG=squidproxy-$NAMESPACE
export VDI_TAG=bastionvm-$NAMESPACE
export ILB_HC=tcp-3128-$NAMESPACE
export IG_NAME=squid-central1-ig-$NAMESPACE
export INSTANCE_GROUP=squid-central1-ig-$NAMESPACE
export BACKEND=squid-backend-service-$NAMESPACE
export ILB_NAME=squid-ilb-central1-$NAMESPACE
export TEST_INSTANCE=test-$NAMESPACE


gcloud beta compute instances delete $TEST_INSTANCE --zone=$ZONE -q
gcloud compute forwarding-rules delete $ILB_NAME --region $REGION -q
gcloud compute backend-services delete $BACKEND --region $REGION -q
gcloud compute instance-groups managed delete  $IG_NAME --zone=$ZONE -q
gcloud compute health-checks delete $ILB_HC -q
gcloud compute firewall-rules delete $PROXY_TAG\-allow-squid -q 
gcloud compute firewall-rules delete $PROXY_TAG\-rules-squid-allow-hc -q
gcloud compute firewall-rules delete $VDI_TAG\-deny-egress -q
gcloud compute firewall-rules delete $PROXY_TAG\-allow-https-egress -q
gcloud compute firewall-rules delete $VDI_TAG\-allow-to-ilb -q
gcloud compute firewall-rules delete  $NETNAME\-allow-ssh -q
gcloud compute instance-templates delete $TEMPLATE_NAME  -q

gcloud compute routers nats delete $NAT_CONF --router=$NAT_ROUTER --region=$REGION  -q
gcloud compute routers delete $NAT_ROUTER --region=$REGION -q
gcloud compute networks subnets delete $SUBNET --region=$REGION -q
gcloud compute networks delete $NETNAME -q
gcloud beta secrets delete $SECRET_NAME -q
gcloud iam service-accounts delete $GCE_SERVICE_ACCOUNT -q
gcloud compute addresses delete $NAT_IP --region $REGION -q
gsutil -m rm -r  gs://$BUCKET_SRC