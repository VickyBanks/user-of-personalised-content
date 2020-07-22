/* IN THE LAST 1 MONTH
1. The number of distinct SI users that have played an episode from...
a. rec row on homepage - DONE
b. end of playback - DONE
c. recommendations page

2. Repeat 1 but find this value as a % of all distinct signed in users.

3. The number of distinct SI users that have played an episode from...
a. homepage continue watching rail -- DONE
b. the my-watching page
c. the top featured episode on a TLEO page (CTA) which can be 'start-watching', 'resume' or 'my-next-episode' - DONE

4. Repeat 3 but find this value as a % of all distinct signed in users.

5. Summary of the above i.e number of distinct SI users that are counted in 1 or 3.
6. Repeat 5 but find this value as a % of all distinct signed in users.


Questions/ What i'm going to do.

i. We have good tracking on TV and Web so I can get what I’ve mentioned for those platforms.
ii. To get this for mobile in a day would be impossible - suggested time frame 6 months perhaps a year. We just don't have the tracking in place for mobile.
iii. I will use distinct users (i.e if they come multiple times they'd only be counted once)
iv. We can define 'plays' from the flags (play-starts sent after 30s, play completes sent after 90% completion). It's normally just as easy to include both as any one individually so I’ll do both. Do you ONLY want user who then actually started the content here? Rather than those who clicked and them never began? I can probably manage clicks, starts and completes.
v. At the end of playback - would this include auto play and/or directly clicking an episode?
    - We have the information to find users who click any content on the episode page and go onto watch it - but this could be at any time in playback.
    - We can try to only select things at the end of playback but this I feel would be far trickier than possible in 1 day.
vi. We can find the visits that clicked to content from a TLEO page, but it will be harder (require new code) to find specifically the visits where the CTA was clicked. I can try, but given the volume of data that needs finding, creating new code and validating it would be tough. So initially I’ll just get users from the TLEO page.
Our process for tracking a user from clicking a homepage module to playing content ignores any TLEO step. So any journey moving homepage-rec-module -> TLEO -> content -> start viewing would give the play start credited to the rec-module.
Our process for tacking at a page level wouldn't ignore that TLEO step so the same journey would be credited as coming from the TLEO page. This will lead to double counting e.g 3.a and 3.c. I will try to eliminate this double counting but it's going to be tricky in the time frame.

Additional Questions/Statements
   - This is looking at VOD content because live content doesn't carry start or complete flags. The VOD content is also the only content in the places asked of the FOI.
   - At the end of playback we can find the users who select or autoplay the suggested content.
   Users can also select the content surfaced below the play window. The content is episodes of the show they're watching.
   However determining if users click these at the end of playback, rather than at some point within playback is very tricky.
   I have looked at users clicking this content in the past and most users who click it do so within the first minute (max 5 minutes) so i don't think it contributes to greatly to end of playback traffic.
   Because of this I haven't included it.

   */




/*

track from modules not including TLEO to get the number from homepage modules
-- this will give us the number from each module ignoring the TLEO
-- this will give us autoplay

track including TLEO
-- this will give us those who click on the CTA.

the differencew will tell us who went rec-module - tleo - content and who just went rec-module - content

Can do
from first script
- number from rec A
from second script
-number from tleo
-number from rec B

Then A-B are the number that went to the TLEO


For end of playback, need things where they click the next rec. Does the next episode count as a recommendation? - no.

 */