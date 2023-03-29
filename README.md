# Azure Mainframe Deployment using Stromasys

This reference architecture shows how to run a mainframe deployment using Stromasys. This baseline follows [Well-Architected Framework](https://learn.microsoft.com/en-us/azure/architecture/framework/) pillars to enable a resilient solution. Some of the key benefits of migrating to a cloud infrastructure using Stromasys are the following: 
* BUSINESS CONTINUITY. Minimal disruption, as all applications, middleware, and data remain as is, and migrate unchanged.
* REDUCED RISK. Charon solutions diminish your risk of unplanned downtime by removing the dependency upon classic hardware
* LOWER COSTS. Charon costs less than a full migration and often less than a single-year of classic hardware support.

## Architecture
![image](/docs/images/malz.png)

## Deploy this scenario
Click on the button below to deploy this accelerator solution:

[![`DTA-Button-ALZ`](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://ms.portal.azure.com/#view/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Flapate%2Fazure-mainframe-landing-zone-public%2Fmain%2Finfra%2Fmain-template%2Fmain.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Flapate%2Fazure-mainframe-landing-zone-public%2Fmain%2Fdocs%2Freference%2Fportal.mainframeLandingZone.json)

You will need to populate certain fields to enable the deployment. To ensure that this accelerator deploys the virtual machines with the marketplace image that was built and is supported by Raincode, you will have to select "Stromasys" for the partner option: 

![image](/docs/images/stromasys_guide.png)


