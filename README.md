Name:- Narasimha Reddy Potlapati
NEUID:- 002774231


In this assignment I have created a VPC and for that created three public subnets and three private subnets each in a different availability zones, created a internet gateway, created routing tables and assigned all subnets to that route tables, and given public subnets destination as 0.0.0.0/0(open to internet)

prerequisites:-
Install AWS command line interface
created dev aws profile for development and created prod(demo) profile for demonstration.

commands to run the terraform files:-
1.terraform init
2.for sanity checks we have to run (terraform plan) -> 
3.terraform apply(security checks not going to break anything and will run thr file)
4.to delete the resources we use this command (terraform destroy)