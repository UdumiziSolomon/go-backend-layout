package database

import (
	"context"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
)

func Connect(databaseUrl string) (*pgxpool.Pool, error) {
	var ctx context.Context = context.Background()

	var config *pgxpool.Config
	var err error

	// Parse the database URL
	config, err = pgxpool.ParseConfig(databaseUrl)

	if err != nil {
		log.Printf("Unable to parse database URL: %v", err)
		return nil, err
	}

	// Connect to the database
	var pool *pgxpool.Pool
	pool, err = pgxpool.NewWithConfig(ctx, config)

	if err != nil {
		log.Printf("Unable to connect to database: %v", err)
		pool.Close()
		return nil, err
	}

	// Ping the database
	err = pool.Ping(ctx)

	if err != nil {
		log.Printf("Unable to ping database: %v", err)
		return nil, err
	}

	// Database is connected
	log.Println("Connected to database")
	return pool, nil
}