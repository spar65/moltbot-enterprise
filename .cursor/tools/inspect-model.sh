#!/usr/bin/env bash
#
# Prisma Model Inspector
# 
# Purpose: Quick inspection of Prisma models with field details and relationships
# Usage: ./.cursor/tools/inspect-model.sh [ModelName] [--relations] [--list]
#
# Examples:
#   ./.cursor/tools/inspect-model.sh HealthCheckApiKey
#   ./.cursor/tools/inspect-model.sh HealthCheckApiKey --relations
#   ./.cursor/tools/inspect-model.sh --list
#
# Exit codes:
#   0 - Success
#   1 - Error (schema not found, invalid model, etc.)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

SCHEMA_PATH="app/prisma/schema.prisma"

# Function to display usage
usage() {
  echo -e "${BLUE}Usage:${NC} $0 [ModelName] [options]"
  echo ""
  echo "Options:"
  echo "  --list          List all available models"
  echo "  --relations     Show model relationships"
  echo "  --help          Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 HealthCheckApiKey"
  echo "  $0 HealthCheckApiKey --relations"
  echo "  $0 --list"
}

# Function to check if schema exists
check_schema() {
  if [ ! -f "$SCHEMA_PATH" ]; then
    echo -e "${RED}❌ ERROR: Prisma schema not found at ${SCHEMA_PATH}${NC}"
    echo "   Run this script from the project root directory."
    exit 1
  fi
}

# Function to list all models
list_models() {
  echo -e "${BLUE}📋 Available Prisma Models:${NC}"
  echo ""
  
  grep "^model " "$SCHEMA_PATH" | awk '{print "  - " $2}' | sort
  
  echo ""
  echo -e "${CYAN}💡 Inspect a model:${NC}"
  echo "   ./.cursor/tools/inspect-model.sh ModelName"
}

# Function to identify field type and suffix pattern
identify_field_pattern() {
  local field_name=$1
  local field_type=$2
  
  case "$field_name" in
    *Json)
      echo -e "${MAGENTA}JSON${NC} (use JSON.stringify/parse)"
      ;;
    *At)
      echo -e "${CYAN}DateTime${NC} (use .toISOString() for API)"
      ;;
    *Id)
      echo -e "${YELLOW}Foreign Key${NC} (UUID reference)"
      ;;
    *Hash)
      echo -e "${RED}Cryptographic Hash${NC} (SHA256, never plain text)"
      ;;
    *ed)
      if [ "$field_type" == "Boolean" ]; then
        echo -e "${GREEN}Boolean Flag${NC}"
      fi
      ;;
    *)
      echo ""
      ;;
  esac
}

# Function to inspect a specific model
inspect_model() {
  local model_name=$1
  local show_relations=${2:-false}
  
  # Check if model exists
  if ! grep -q "^model $model_name" "$SCHEMA_PATH"; then
    echo -e "${RED}❌ ERROR: Model '${model_name}' not found in schema${NC}"
    echo ""
    echo -e "${YELLOW}💡 TIP: Run with --list to see available models${NC}"
    exit 1
  fi
  
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  Model: ${model_name}${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  
  # Extract model definition
  local model_content=$(sed -n "/^model $model_name/,/^}/p" "$SCHEMA_PATH")
  
  # Display fields
  echo -e "${CYAN}📋 Fields:${NC}"
  echo ""
  
  echo "$model_content" | grep -v "^model" | grep -v "^}" | grep -v "@@" | while read -r line; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*// ]]; then
      continue
    fi
    
    # Parse field line
    field_name=$(echo "$line" | awk '{print $1}')
    field_type=$(echo "$line" | awk '{print $2}' | sed 's/@.*//' | sed 's/\?//')
    
    # Check for special attributes
    is_primary=""
    is_unique=""
    is_optional=""
    is_relation=""
    
    if echo "$line" | grep -q "@id"; then
      is_primary=" ${GREEN}[Primary Key]${NC}"
    fi
    
    if echo "$line" | grep -q "@unique"; then
      is_unique=" ${YELLOW}[Unique]${NC}"
    fi
    
    if echo "$line" | grep -q "?"; then
      is_optional=" ${CYAN}[Optional]${NC}"
    fi
    
    if echo "$line" | grep -q "@relation"; then
      is_relation=" ${MAGENTA}[Relation]${NC}"
    fi
    
    # Get field pattern
    pattern=$(identify_field_pattern "$field_name" "$field_type")
    
    # Display field
    echo -e "  - ${BLUE}${field_name}${NC}: ${field_type}${is_primary}${is_unique}${is_optional}${is_relation}"
    
    if [ -n "$pattern" ]; then
      echo -e "    └─ $pattern"
    fi
  done
  
  echo ""
  
  # Display indexes
  echo -e "${CYAN}🔍 Indexes:${NC}"
  echo ""
  
  if echo "$model_content" | grep -q "@@index\|@@unique"; then
    echo "$model_content" | grep "@@index\|@@unique" | while read -r line; do
      echo "  - $line"
    done
  else
    echo "  (No custom indexes defined)"
  fi
  
  echo ""
  
  # Display relationships if requested
  if [ "$show_relations" == "true" ]; then
    echo -e "${CYAN}🔗 Relationships:${NC}"
    echo ""
    
    local has_relations=false
    echo "$model_content" | grep "@relation" | while read -r line; do
      has_relations=true
      field_name=$(echo "$line" | awk '{print $1}')
      relation_type=$(echo "$line" | awk '{print $2}' | sed 's/\?//')
      
      # Check for onDelete
      on_delete=""
      if echo "$line" | grep -q "onDelete:"; then
        on_delete_action=$(echo "$line" | sed -n 's/.*onDelete: \([^,)]*\).*/\1/p')
        on_delete=" ${RED}[onDelete: ${on_delete_action}]${NC}"
      fi
      
      echo -e "  - ${BLUE}${field_name}${NC} → ${relation_type}${on_delete}"
    done
    
    if ! echo "$model_content" | grep -q "@relation"; then
      echo "  (No relationships defined)"
    fi
    
    echo ""
  fi
  
  # TypeScript import example
  echo -e "${CYAN}💻 TypeScript Import:${NC}"
  echo ""
  echo -e "  ${GREEN}import { ${model_name} } from '@prisma/client';${NC}"
  echo ""
  echo -e "  ${YELLOW}const record: ${model_name} = await prisma.${model_name,,}.create({${NC}"
  echo -e "  ${YELLOW}  data: { ... }${NC}"
  echo -e "  ${YELLOW}});${NC}"
  echo ""
  
  # Direct vs Indirect organizationId check
  if echo "$model_content" | grep -q "organizationId"; then
    echo -e "${GREEN}✅ Direct Relationship:${NC} Model HAS organizationId field"
    echo -e "   ${CYAN}Query:${NC} prisma.${model_name,,}.findMany({ where: { organizationId } })"
  else
    echo -e "${YELLOW}⚠️  Indirect Relationship:${NC} Model does NOT have organizationId"
    echo -e "   ${CYAN}Query:${NC} Use nested query via parent relation"
    echo -e "   ${CYAN}Example:${NC} prisma.${model_name,,}.findMany({ where: { parent: { organizationId } } })"
  fi
  
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

# Main script logic
main() {
  check_schema
  
  # Parse arguments
  if [ $# -eq 0 ]; then
    usage
    exit 1
  fi
  
  case "$1" in
    --list)
      list_models
      ;;
    --help)
      usage
      ;;
    *)
      model_name=$1
      show_relations=false
      
      if [ $# -ge 2 ] && [ "$2" == "--relations" ]; then
        show_relations=true
      fi
      
      inspect_model "$model_name" "$show_relations"
      ;;
  esac
}

main "$@"

