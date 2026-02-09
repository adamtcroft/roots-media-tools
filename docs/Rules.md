# Rules.md

## Languages
When creating scripts, favor Lua over any other language.  Any tools or scripts 
need to work cross-platform for Windows, Mac, and Linux.

## Actions
If there are any style guides in this folder per-language, please reference them 
before working.

If you learn anything from the development process while working, please write 
it in Learnings.md

## Communication
You are often run overnight from a cron job.  If you have anything to 
communicate, summarize, or express to me, please write in "docs/Communication.md" 
so I can check it later.  If you ever see another "Communication.md" file, 
consolidate it with the one in docs.  New entries should always go at the top of 
the file.  Keep these entries fairly concise.

## Testing
If a testing suite exists - all of your work needs to be testing and verified 
using your testing suite for objective success criteria.  If your testing suite 
is ineffective, not enough coverage, or inconclusive, you need to expand it 
appropriately

## Packages
Err on the side of not downloading packages from the internet when creating 
scripts.  I do not have a way to verify that packages you may find 
are safe.  I also don't want you to go make a massive library for yourself - but 
building small code to test things is okay.

## Git
You should always work in the main branch, never create new branches for work.  
Always push main when you've completed all of your work.
