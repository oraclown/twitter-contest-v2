# Twitter Contest V2

## streak shield implementation
### done
- users can buy streak shield before the contest starts for cheaper
- users can buy streak shield during the contest for more
### todo
- if someone calls claimLoser correctly on another contestant, they get like 10% of that player's stake no matter what, and the loser's status "inTheRunning" is set to false. This means their entire stake is in jeopardy, and will be distributed to the winners at the end.
- if someone calls claimLoser correctly on a contestant who is "inTheRunning" but has a streak shield, they still get 10% of that player's stake, but the loser's status "inTheRunning" is NOT set to false. This means their entire stake is NOT in jeopardy, and will NOT be distributed to the winners at the end. The loser's streak shield count is decremented.
-

## Replit setup
- run `source ./setup.sh`