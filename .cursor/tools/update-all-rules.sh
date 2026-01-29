#!/usr/bin/env bash
#
# Batch Rule Updater - Add "See Also" sections to all rules
#
# Purpose: Systematically add cross-references to remaining 142 rules
# Usage: ./update-all-rules.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

RULES_DIR=".cursor/rules"
UPDATED=0
SKIPPED=0

echo -e "${BLUE}🔥 Starting GOAT-level rule updates...${NC}"
echo ""

# Template for See Also section
create_see_also() {
  cat << 'EOF'

## See Also

### Documentation
- **`.cursor/docs/rules-guide.md`** - Understanding the rule system
- **`.cursor/docs/ai-workflows.md`** - Proven development patterns
- **`.cursor/rules/003-cursor-system-overview.mdc`** - System overview (READ THIS FIRST)

### Tools
- **`.cursor/tools/inspect-model.sh`** - Schema inspection (use before database work)
- **`.cursor/tools/check-schema-changes.sh`** - Validate changes

### Related Rules
- @002-rule-application.mdc - Rule priority and Source of Truth Hierarchy
- @003-cursor-system-overview.mdc - Complete system overview

EOF
}

# Process each rule file
for rule_file in "$RULES_DIR"/*.mdc; do
  # Skip if already has See Also section
  if grep -q "## See Also" "$rule_file"; then
    echo -e "${BLUE}⏭️  Skipping$(basename "$rule_file") (already has See Also)${NC}"
    ((SKIPPED++))
    continue
  fi
  
  # Skip special files
  filename=$(basename "$rule_file")
  if [[ "$filename" == "000-"* ]] || [[ "$filename" == "001-"* ]] || [[ "$filename" == "002-"* ]] || [[ "$filename" == "003-"* ]]; then
    echo -e "${BLUE}⏭️  Skipping $filename (system file)${NC}"
    ((SKIPPED++))
    continue
  fi
  
  # Add See Also section
  echo -e "${GREEN}✅ Updating $filename${NC}"
  create_see_also >> "$rule_file"
  ((UPDATED++))
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  GOAT-LEVEL UPDATE COMPLETE!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo -e "  ✅ Updated: ${GREEN}$UPDATED${NC} rules"
echo -e "  ⏭️  Skipped: ${BLUE}$SKIPPED${NC} rules (already done)"
echo ""
echo -e "${BLUE}🎉 All rules now cross-reference docs and tools!${NC}"
echo ""

