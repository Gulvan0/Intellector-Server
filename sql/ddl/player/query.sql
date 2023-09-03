CREATE TABLE player.query (
    owner_login VARCHAR(16) NOT NULL,
    query_name VARCHAR(40) NOT NULL,
    query_text TEXT NOT NULL,

    INDEX owner_login_ind (owner_login),

    FOREIGN KEY (owner_login) 
        REFERENCES player.player (player_login)
)