package database;

enum abstract QueryShortcut(String) to String 
{
    var CreateCorrespondenceChallenge = "sql/dml/challenges/create_correspondence.sql";
    var CreateFischerChallenge = "sql/dml/challenges/create_fischer.sql";
    var DeactivateChallenge = "sql/dml/challenges/deactivate.sql";
    var GetActiveIncomingChallenges = "sql/dml/challenges/get_active_incoming.sql";
    var GetActivePublicChallenges = "sql/dml/challenges/get_active_public.sql";
    var GetOpenChallengeByID = "sql/dml/challenges/get_open_by_id.sql";

    var StartFischerGame = "sql/dml/game_process/start_fischer_game.sql";
    var StartCorrespondenceGame = "sql/dml/game_process/start_correspondence_game.sql";
    var OnPly = "sql/dml/game_process/on_ply.sql";
    var OnOffer = "sql/dml/game_process/on_offer.sql";
    var OnMessage = "sql/dml/game_process/on_message.sql";
    var OnRollback = "sql/dml/game_process/on_rollback.sql";
    var OnTimeAdded = "sql/dml/game_process/on_time_added.sql";
    var OnGameEnded = "sql/dml/game_process/on_game_ended.sql";

    var LogAntifraud = "sql/dml/logging/append_antifraud.sql";
    var LogMessage = "sql/dml/logging/append_message.sql";
    var LogService = "sql/dml/logging/append_service.sql";

    var CheckDatabaseEmptyness = "sql/dml/on_start/check_if_database_empty.sql";
    var GetUnfinishedFiniteGames = "sql/dml/on_start/get_unfinished_finite_games.sql";

    var GetGameToFollow = "sql/dml/player/get_game_to_follow.sql";
}