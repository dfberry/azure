#!/bin/bash
# Azure CLI script to list resources ordered by creation date
# This script shows all resources in your subscription, sorted by creation time

# Prerequisites:
# - Azure CLI installed and configured
# - jq installed for JSON parsing
# `az login` must be run to authenticate to Azure before running this script
# `chmod +x new-resources.sh`

# Exit on error
set -e

# Configuration - you can modify these variables
MAX_RESOURCES=100  # Maximum number of resources to show
DATE_FORMAT="%Y-%m-%d %H:%M:%S"  # Format for displaying dates
SUBSCRIPTION_NAME=""  # Leave empty to use default subscription

# ANSI color codes for prettier output
RESET="\033[0m"
BOLD="\033[1m"
BLUE="\033[34m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"

echo -e "${BOLD}=== Azure Resources By Creation Date ===${RESET}"
echo ""

# Get current subscription info if not specified
if [ -z "$SUBSCRIPTION_NAME" ]; then
    SUBSCRIPTION_INFO=$(az account show)
    SUBSCRIPTION_ID=$(echo $SUBSCRIPTION_INFO | jq -r '.id')
    SUBSCRIPTION_NAME=$(echo $SUBSCRIPTION_INFO | jq -r '.name')
else
    # Set to the specified subscription
    az account set --subscription "$SUBSCRIPTION_NAME"
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
fi

echo -e "${BOLD}Subscription:${RESET} $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo -e "${BOLD}Date:${RESET} $(date +"$DATE_FORMAT")"
echo ""

# Get all resources in the subscription with creation time
echo -e "${YELLOW}Fetching resources... This may take a moment${RESET}"
echo ""

RESOURCES=$(az resource list --query "[].{name:name, resourceGroup:resourceGroup, type:type, location:location, createdTime:createdTime}" -o json)

# Count the total number of resources
TOTAL_RESOURCES=$(echo $RESOURCES | jq '. | length')

echo -e "${BOLD}${GREEN}Found $TOTAL_RESOURCES resources in subscription${RESET}"
echo ""

# Sort resources by creation time
SORTED_RESOURCES=$(echo $RESOURCES | jq 'sort_by(.createdTime)')

# Display resources in a table format
echo -e "${BOLD}${BLUE}Resources by Creation Date (Most Recent First):${RESET}"
echo -e "${BOLD}--------------------------------------------------------------${RESET}"
printf "${BOLD}%-25s %-25s %-30s %-20s %-30s${RESET}\n" "Resource Group" "Name" "Type" "Location" "Created Time"
echo -e "${BOLD}--------------------------------------------------------------${RESET}"

# Display resources in reverse order (newest first) with limit
echo $SORTED_RESOURCES | jq -r "reverse | .[0:$MAX_RESOURCES][] | \"\\(.resourceGroup)\t\\(.name)\t\\(.type)\t\\(.location)\t\\(.createdTime)\"" | 
while IFS=$'\t' read -r rg name type location created; do
    # Format the creation date if not null
    if [ "$created" != "null" ]; then
        # Format the date - different systems may require different date formats
        created_formatted=$(date -d "$created" +"$DATE_FORMAT" 2>/dev/null || echo "$created")
    else
        created_formatted="Unknown"
    fi
    
    # Truncate long values for better display
    if [ ${#name} -gt 25 ]; then
        name="${name:0:22}..."
    fi
    if [ ${#type} -gt 30 ]; then
        type="${type:0:27}..."
    fi
    
    printf "%-25s %-25s %-30s %-20s %-30s\n" "$rg" "$name" "$type" "$location" "$created_formatted"
done

echo -e "${BOLD}--------------------------------------------------------------${RESET}"

# Show counts by resource type
echo ""
echo -e "${BOLD}${CYAN}Resource Counts by Type:${RESET}"
echo $RESOURCES | jq -r '.[].type' | sort | uniq -c | sort -nr | 
while read -r count type; do
    printf "%-5s %s\n" "$count" "$type"
done

echo ""
echo -e "${YELLOW}Note: Some resources might not have creation time data available.${RESET}"
echo -e "${YELLOW}Showing up to $MAX_RESOURCES resources. Edit MAX_RESOURCES variable to see more.${RESET}"

# Save the output to a file
OUTPUT_FILE="azure_resources_$(date +"%Y%m%d_%H%M%S").txt"
echo "Saving detailed resource list to $OUTPUT_FILE"

{
echo "Azure Resources By Creation Date"
echo "==============================="
echo "Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo "Date: $(date +"$DATE_FORMAT")"
echo "Total Resources: $TOTAL_RESOURCES"
echo ""
echo "Resources by Creation Date (Most Recent First):"
echo "--------------------------------------------------------------"
printf "%-25s %-25s %-30s %-20s %-30s\n" "Resource Group" "Name" "Type" "Location" "Created Time"
echo "--------------------------------------------------------------"

echo $SORTED_RESOURCES | jq -r "reverse | .[] | \"\\(.resourceGroup)\t\\(.name)\t\\(.type)\t\\(.location)\t\\(.createdTime)\"" | 
while IFS=$'\t' read -r rg name type location created; do
    if [ "$created" != "null" ]; then
        created_formatted=$(date -d "$created" +"$DATE_FORMAT" 2>/dev/null || echo "$created")
    else
        created_formatted="Unknown"
    fi
    printf "%-25s %-25s %-30s %-20s %-30s\n" "$rg" "$name" "$type" "$location" "$created_formatted"
done
} > "$OUTPUT_FILE"

echo -e "${GREEN}Done! Full resource list saved to $OUTPUT_FILE${RESET}"
