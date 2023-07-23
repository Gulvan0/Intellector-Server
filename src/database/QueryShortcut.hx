package database;

enum abstract QueryShortcut(String) to String 
{
    var GetActiveIncomingChallenges = "sql/dml/challenges/get_active_incoming.sql";
    var GetActivePublicChallenges = "sql/dml/challenges/get_active_public.sql";
    var GetOpenChallengeByID = "sql/dml/challenges/get_open_by_id.sql";

    var GetGameDataByID = "sql/dml/game/get_by_id.sql";
    var GetGameEventsByID = "sql/dml/game/get_events_by_id.sql";

    var CheckDatabaseEmptyness = "sql/dml/on_start/check_if_database_empty.sql";
    var GetUnfinishedFiniteGames = "sql/dml/on_start/get_unfinished_finite_games.sql";

    var GetGameToFollow = "sql/dml/player/get_game_to_follow.sql";
}