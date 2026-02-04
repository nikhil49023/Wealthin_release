BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "budgets" (
    "id" bigserial PRIMARY KEY,
    "name" text NOT NULL,
    "amount" double precision NOT NULL,
    "spent" double precision NOT NULL,
    "icon" text NOT NULL,
    "userProfileId" bigint NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "goals" (
    "id" bigserial PRIMARY KEY,
    "name" text NOT NULL,
    "targetAmount" double precision NOT NULL,
    "currentAmount" double precision NOT NULL,
    "isDefault" boolean NOT NULL,
    "userProfileId" bigint NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "transactions" (
    "id" bigserial PRIMARY KEY,
    "amount" double precision NOT NULL,
    "description" text NOT NULL,
    "date" timestamp without time zone NOT NULL,
    "type" text NOT NULL,
    "category" text NOT NULL,
    "userProfileId" bigint NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "user_profiles" (
    "id" bigserial PRIMARY KEY,
    "uid" text NOT NULL,
    "credits" bigint NOT NULL,
    "completedGoals" json
);

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "budgets"
    ADD CONSTRAINT "budgets_fk_0"
    FOREIGN KEY("userProfileId")
    REFERENCES "user_profiles"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "goals"
    ADD CONSTRAINT "goals_fk_0"
    FOREIGN KEY("userProfileId")
    REFERENCES "user_profiles"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "transactions"
    ADD CONSTRAINT "transactions_fk_0"
    FOREIGN KEY("userProfileId")
    REFERENCES "user_profiles"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR wealthin
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wealthin', '20260128102320302', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260128102320302', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20251208110333922-v3-0-0', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251208110333922-v3-0-0', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260109031533194', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260109031533194', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20251208110412389-v3-0-0', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251208110412389-v3-0-0', "timestamp" = now();


COMMIT;
