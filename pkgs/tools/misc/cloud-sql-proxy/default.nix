{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "cloud-sql-proxy";
  version = "2.5.0";

  src = fetchFromGitHub {
    owner = "GoogleCloudPlatform";
    repo = "cloud-sql-proxy";
    rev = "v${version}";
    sha256 = "sha256-0MqnFTIkjhuptnEvNV7ehbTu9a6ZsC1yL/+ZZVz67To=";
  };

  subPackages = [ "." ];

  vendorSha256 = "sha256-VadE9E4B8BIIHGl+PN4oDl0H56xE3GQn0MxGw5fGsvM=";

  preCheck = ''
    buildFlagsArray+="-short"
  '';

  meta = with lib; {
    description = "Utility for ensuring secure connections to Google Cloud SQL instances";
    homepage = "https://github.com/GoogleCloudPlatform/cloud-sql-proxy";
    license = licenses.asl20;
    maintainers = with maintainers; [ nicknovitski totoroot ];
    mainProgram = "cloud-sql-proxy";
  };
}
