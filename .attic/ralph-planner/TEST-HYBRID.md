# Ralph Planner Hybrid Mode - Test Plan

## Test Scenario 1: Start Hybrid Mode
```bash
/ralph-planner-start "Build a simple todo API"
```
**Expected:**
- Creates `.claude.ralph-planner-hybrid.local.md` state file
- Sets phase to "planning"
- Creates `.planning/` directory structure
- Shows activation message

## Test Scenario 2: Planning Phase
**User actions:**
1. Ralph creates BRIEF.md
2. Ralph creates ROADMAP.md
3. Ralph creates phase plans
4. User outputs: `promisePLANNING COMPLETEpromise`

**Expected:**
- Auto-conversion to goals.xml triggers
- Phase changes to "orchestration"
- State file updated with new phase

## Test Scenario 3: Orchestration Phase
**User actions:**
1. Work on goals sequentially
2. Output: `promiseGOAL G1 DONEpromise`
3. Repeat for all goals
4. Output: `promiseALL GOALS COMPLETEpromise`

**Expected:**
- Goals.xml updated with completion
- Iteration counter increments
- Progress tracking updates
- Loop terminates when complete

## Test Scenario 4: Natural Stop
**User action:**
Type "stop" in conversation

**Expected:**
- Stop hook detects "stop" keyword
- Graceful shutdown
- Work preserved
- State file removed

## Test Scenario 5: Emergency Stop
```bash
/ralph-planner-stop
```
**Expected:**
- State file removed
- Work preserved
- Message shows artifacts preserved

## Test Scenario 6: Built-in Status
**During loop:**
- Status displays automatically
- Shows current phase
- Shows iteration count
- Shows progress bars
- Shows file status

## Test Scenario 7: Smart Detection
**User input:** "I need to build a REST API"
**Expected:**
- Ralph detects planning intent
- Offers to start Ralph Wiggum loop
- User confirms with "yes"
- Loop starts with planning

## Test Scenario 8: Migration from Old State
**Setup:**
1. Start with old planning loop: `/ralph-plan "Build API"`
2. Convert to hybrid: `/ralph-planner-start "Build API"`

**Expected:**
- Hybrid script detects existing state
- Migrates to hybrid mode
- Continues from where left off

## Verification Commands
```bash
# Check state file
cat .claude.ralph-planner-hybrid.local.md

# Check planning artifacts
ls -la .planning/

# Check goals
cat .ralph/goals.xml

# Run status
bash scripts/display-status.sh
```
