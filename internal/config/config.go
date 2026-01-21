package config

import (
	"log"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DatabaseUrl string
	Port        string
}

func Load() (*Config, error) {
	// Load .env file
	var err error = godotenv.Load()

	if err != nil {
		log.Println("Error loading .env file")
	}

	// Get environment variables
	var config *Config = &Config{
		DatabaseUrl: os.Getenv("DATABASE_URL"),
		Port:        os.Getenv("PORT"),
	}

	return config, nil
}
