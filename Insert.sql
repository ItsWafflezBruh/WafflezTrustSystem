CREATE TABLE IF NOT EXISTS vehicle_spawn_ownership (
    spawncode VARCHAR(60) PRIMARY KEY,
    owner_identifier VARCHAR(80) NOT NULL,
    access JSON NOT NULL
);