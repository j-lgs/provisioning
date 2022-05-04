#protoc --proto_path=api/talos/ --proto_path=api/talos/vendor/ api/talos/common/*.proto api/talos/machine/*.proto --go_out=gen --go-grpc_out=gen --go_opt=paths=source_relative --go-grpc_opt=paths=source_relative 
mkdir -p build/
go build -o terraform-provider-talos
#rm build/terraform-provider-talos
mv terraform-provider-talos build/
chmod +x build/terraform-provider-talos
