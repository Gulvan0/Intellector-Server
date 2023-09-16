::do var encloseStr = (s:String) -> ("(" + s + ")")::
::do var quoteStr = (s:String) -> ("'" + s + "'")::
::do var inCondition = (expr:String, vals:Array<Null<String>>) -> encloseStr((vals.contains(null)? expr + " IS NULL OR " : "") + expr + " IN " + encloseStr(vals.filter(x -> x != null).map(quoteStr).join(", ")))::

DROP TEMPORARY TABLE IF EXISTS tmp.game_ids;

CREATE TEMPORARY TABLE tmp.game_ids
SELECT 
    id
FROM game.game AS game
WHERE 1=1
::for (batch in filterBatches)::
    OR 1=1
    ::for (singleFilter in filterBatches)::
        ::do var fdata = singleFilter.data::

        AND
        ::if (singleFilter.not)::
            NOT
        ::end::

        ::if (singleFilter.type == 'player')::
            ::if (fdata.color == 'white')::
                ::inCondition("game.white_player_ref", fdata.logins)::
            ::elseif (fdata.color == 'black')::
                ::inCondition("game.black_player_ref", fdata.logins)::
            ::else::
                (::inCondition("game.white_player_ref", fdata.logins):: OR ::inCondition("game.black_player_ref", fdata.logins)::)
            ::end::
        ::elseif (singleFilter.type == 'timeControlType')::
            ::inCondition("game.time_control_type", fdata.types)::
        ::elseif (singleFilter.type == 'rated')::
            game.rated
        ::elseif (singleFilter.type == 'startTsFrame')::
            1=1
            ::if (fdata.lowerThreshold != null)::
                AND game.start_secs >= ::fdata.lowerThreshold::
            ::end::
            ::if (fdata.upperThreshold != null)::
                AND game.start_secs <= ::fdata.upperThreshold::
            ::end::
        ::elseif (singleFilter.type == 'outcomeType')::
            ::inCondition("game.outcome_type", fdata.outcomeTypes)::
        ::elseif (singleFilter.type == 'winnerColor')::
            ::inCondition("game.winner_color", fdata.winnerColors)::
        ::elseif (singleFilter.type == 'startingSIP')::
            game.id IN (
                SELECT 
                    game_id
                FROM game.encountered_situation
                WHERE ply_num = 0
                AND ::inCondition("sip", fdata.sips)::
            )
        ::elseif (singleFilter.type == 'anySIP')::
            game.id IN (
                SELECT 
                    game_id
                FROM game.encountered_situation
                WHERE ::inCondition("sip", fdata.sips)::
            )
        ::elseif (singleFilter.type == 'lastSIP')::
            game.id IN (
                SELECT 
                    orig.game_id
                FROM game.encountered_situation AS orig
                INNER JOIN (
                    SELECT
                        game_id,
                        MAX(ply_num) AS last_ply_num
                    FROM game.encountered_situation
                    GROUP BY game_id
                ) AS last_plys
                ON orig.game_id = last_plys.game_id
                WHERE orig.ply_num = last_plys.last_ply_num
                AND ::inCondition("orig.sip", fdata.sips)::
            )
        ::elseif (singleFilter.type == 'moveCntFrame')::
            game.id IN (
                SELECT
                    game_id
                FROM game.encountered_situation
                GROUP BY game_id
                HAVING 1=1
                ::if (fdata.lowerThreshold != null)::
                    AND MAX(ply_num) >= ::fdata.lowerThreshold::
                ::end::
                ::if (fdata.upperThreshold != null)::
                    AND MAX(ply_num) <= ::fdata.upperThreshold::
                ::end::
            )
        ::elseif (singleFilter.type == 'tcFrame')::
            game.id IN (
                SELECT
                    game_id
                FROM game.fischer_time_control
                WHERE
                    ::if (fdata.constrainedValue == 'startSecs')::
                        start_secs
                    ::elseif (fdata.constrainedValue == 'bonusSecs')::
                        increment_secs
                    ::else::
                        start_secs + ::fdata.slope:: * increment_secs
                    ::end::

                    ::if (fdata.lowerThreshold != null && fdata.upperThreshold != null)::
                        BETWEEN ::fdata.lowerThreshold:: AND ::fdata.upperThreshold::
                    ::elseif (fdata.lowerThreshold != null)::
                        >= ::fdata.lowerThreshold::
                    ::else::
                        <= ::fdata.upperThreshold::
                    ::end::
            )
        ::elseif (singleFilter.type == 'eloFrame')::
            game.id IN (
                SELECT
                    gdata.id
                FROM game.game AS gdata
                INNER JOIN player.ranked_progress AS rprog
                ON gdata.time_control_type = rprog.time_control_type
                ::if (fdata.color == 'white')::
                    AND rprog.player_login = gdata.white_player_ref
                ::elseif (fdata.color == 'black')::
                    AND rprog.player_login = gdata.black_player_ref
                ::else::
                    AND (rprog.player_login = gdata.white_player_ref OR rprog.player_login = gdata.black_player_ref)
                ::end::
                WHERE
                    rprog.ts = (
                        SELECT
                            player_login,
                            time_control_type,
                            MAX(ts) AS relevance_ts
                        FROM player.ranked_progress
                        WHERE player_login = rprog.player_login
                        AND time_control_type = rprog.time_control_type
                        ::if (fdata.atGameStart)::
                            AND ts <= gdata.start_ts
                        ::end::
                    )
                ::if (fdata.lowerThreshold != null)::
                    AND rprog.elo >= ::fdata.lowerThreshold::
                ::end::
                ::if (fdata.upperThreshold != null)::
                    AND rprog.elo <= ::fdata.upperThreshold::
                ::end::
                ::if (fdata.minRelevantGamesCnt != null)::
                    AND rprog.relevant_rated_games_cnt >= ::fdata.minRelevantGamesCnt::
                ::end::
            )
        ::end::
    ::end::
::end::