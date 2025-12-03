# Check GPU Quota for KAITO on AKS

This executable guide validates GPU vCPU quota for a chosen
`AZURE_GPU_VM_SIZE` in a given `AZURE_LOCATION` before running KAITO
installation or deploying workspaces. It also enforces a configurable
minimum number of available vCPUs.

## Prerequisites

- Azure CLI (`az`) installed and logged in.
- `jq` installed for JSON parsing.

## Environment

This section defines the Azure environment variables used by the quota check,
including the minimum number of available vCPUs required.

```bash
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
export AZURE_LOCATION="${AZURE_LOCATION:-eastus2}"
export AZURE_GPU_VM_SIZE="${AZURE_GPU_VM_SIZE:-Standard_NC40ads_H100_v5}"
export AZURE_MIN_GPU_VCPUS="${AZURE_MIN_GPU_VCPUS:-3}"
```

## GPU Quota Check

This section queries Azure to validate that there are available vCPUs for the selected GPU SKU.

```bash
echo "Checking GPU quota for ${AZURE_GPU_VM_SIZE} in ${AZURE_LOCATION}..."

SKU_INFO=$(az vm list-skus --location "${AZURE_LOCATION}" \
	--size "${AZURE_GPU_VM_SIZE}" \
	--resource-type virtualMachines \
	--output json 2>/dev/null | jq -r '.[0].family' 2>/dev/null)

if [ -z "${SKU_INFO}" ] || [ "${SKU_INFO}" = "null" ]; then
	echo "Could not determine VM family for ${AZURE_GPU_VM_SIZE}"
	echo "Attempting to list all GPU quota..."
	QUOTA_CHECK=$(az vm list-usage --location "${AZURE_LOCATION}" \
		--query "[?contains(name.value, 'NC') || contains(name.value, 'ND')]" \
		-o json 2>/dev/null)
else
	echo "VM Family: ${SKU_INFO}"
	QUOTA_CHECK=$(az vm list-usage --location "${AZURE_LOCATION}" \
		--query "[?name.value=='${SKU_INFO}']" \
		-o json 2>/dev/null)
fi

if [ -n "${QUOTA_CHECK}" ] && [ "${QUOTA_CHECK}" != "[]" ]; then
	echo "${QUOTA_CHECK}" | jq -r '.[] |
		"VM Family: \(.name.localizedValue)\n" +
		"  Current: \(.currentValue) vCPUs\n" +
		"  Limit: \(.limit) vCPUs\n" +
		"  Available: \((.limit | tonumber) - (.currentValue | tonumber)) vCPUs"'

	AVAILABLE=$(echo "${QUOTA_CHECK}" | jq -r '.[0] | ((.limit | tonumber) - (.currentValue | tonumber))')

	if [ "${AVAILABLE}" -lt "${AZURE_MIN_GPU_VCPUS}" ]; then
		echo ""
		echo "ERROR: Insufficient available vCPUs for ${AZURE_GPU_VM_SIZE} in ${AZURE_LOCATION}."
		echo "       Required: ${AZURE_MIN_GPU_VCPUS} vCPUs, Available: ${AVAILABLE} vCPUs."
		echo "       Request quota increase or choose a smaller GPU SKU before continuing."
		exit 1
	fi

	echo ""
	echo "✓ GPU quota is allocated (Available: ${AVAILABLE} vCPUs)"
else
	echo "Could not retrieve GPU quota information for ${AZURE_LOCATION}"
	echo "Verify GPU VM families are available in this region"
	exit 1
fi
```

<!-- expected_similarity="Available: .* vCPUs" -->

```text
Checking GPU quota in eastus2...
VM Family: Standard NCASv3_T4 Family vCPUs
	Current: 0 vCPUs
	Limit: 24 vCPUs
	Available: 24 vCPUs

✓ GPU quota is allocated (Available: 24 vCPUs)
```
