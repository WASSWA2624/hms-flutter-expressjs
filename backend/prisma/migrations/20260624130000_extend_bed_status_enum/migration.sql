-- Extend bed operational statuses for IPD bed board (cleaning, maintenance, blocked).
ALTER TYPE "BedStatus" ADD VALUE IF NOT EXISTS 'CLEANING';
ALTER TYPE "BedStatus" ADD VALUE IF NOT EXISTS 'MAINTENANCE';
ALTER TYPE "BedStatus" ADD VALUE IF NOT EXISTS 'BLOCKED';
