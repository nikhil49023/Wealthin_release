BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "agent_actions" (
    "id" bigserial PRIMARY KEY,
    "userProfileId" bigint NOT NULL,
    "actionType" text NOT NULL,
    "parameters" text NOT NULL,
    "status" text NOT NULL,
    "resultMessage" text,
    "createdAt" timestamp without time zone NOT NULL,
    "executedAt" timestamp without time zone,
    "relatedEntityId" bigint,
    "relatedEntityType" text
);

-- Indexes
CREATE INDEX "action_user_idx" ON "agent_actions" USING btree ("userProfileId");
CREATE INDEX "action_status_idx" ON "agent_actions" USING btree ("userProfileId", "status");

--
-- ACTION ALTER TABLE
--
ALTER TABLE "budgets" ADD COLUMN "category" text;
ALTER TABLE "budgets" ADD COLUMN "limit" double precision;
ALTER TABLE "budgets" ADD COLUMN "period" text;
ALTER TABLE "budgets" ADD COLUMN "createdAt" timestamp without time zone;
ALTER TABLE "budgets" ADD COLUMN "updatedAt" timestamp without time zone;
CREATE INDEX "budget_user_category_idx" ON "budgets" USING btree ("userProfileId", "category");
--
-- ACTION CREATE TABLE
--
CREATE TABLE "debts" (
    "id" bigserial PRIMARY KEY,
    "userProfileId" bigint NOT NULL,
    "name" text NOT NULL,
    "debtType" text NOT NULL,
    "principal" double precision NOT NULL,
    "interestRate" double precision NOT NULL,
    "emi" double precision,
    "startDate" timestamp without time zone NOT NULL,
    "tenureMonths" bigint,
    "remainingAmount" double precision NOT NULL,
    "nextDueDate" timestamp without time zone,
    "status" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone,
    "notes" text
);

-- Indexes
CREATE INDEX "debt_user_idx" ON "debts" USING btree ("userProfileId");
CREATE INDEX "debt_status_idx" ON "debts" USING btree ("userProfileId", "status");

--
-- ACTION ALTER TABLE
--
ALTER TABLE "goals" ADD COLUMN "deadline" timestamp without time zone;
ALTER TABLE "goals" ADD COLUMN "status" text;
ALTER TABLE "goals" ADD COLUMN "createdAt" timestamp without time zone;
ALTER TABLE "goals" ADD COLUMN "updatedAt" timestamp without time zone;
ALTER TABLE "goals" ADD COLUMN "notes" text;
CREATE INDEX "goal_user_idx" ON "goals" USING btree ("userProfileId");
--
-- ACTION CREATE TABLE
--
CREATE TABLE "scheduled_payments" (
    "id" bigserial PRIMARY KEY,
    "userProfileId" bigint NOT NULL,
    "name" text NOT NULL,
    "amount" double precision NOT NULL,
    "frequency" text NOT NULL,
    "nextDueDate" timestamp without time zone NOT NULL,
    "autoTrack" boolean NOT NULL,
    "category" text,
    "isActive" boolean NOT NULL,
    "lastPaidDate" timestamp without time zone,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone,
    "notes" text
);

-- Indexes
CREATE INDEX "payment_user_idx" ON "scheduled_payments" USING btree ("userProfileId");
CREATE INDEX "payment_due_idx" ON "scheduled_payments" USING btree ("userProfileId", "nextDueDate", "isActive");


--
-- MIGRATION VERSION FOR wealthin
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wealthin', '20260128172715582', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260128172715582', "timestamp" = now();

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
