UPDATE challenge.challenge
SET
    active = 0,
    resulting_game_id = {resulting_game_id}
WHERE id = {challenge_id}