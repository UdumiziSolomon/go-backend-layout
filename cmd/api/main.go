package main

import (
	"log"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/solonode/go-learn/internal/config"
	"github.com/solonode/go-learn/internal/database"
	"github.com/solonode/go-learn/internal/handlers"
)

func main() {
	// Load configuration
	var cfg *config.Config
	var err error
	cfg, err = config.Load()

	if err != nil {
		log.Fatal("Failed to load configuration", err)
	}

	// Connect to the database
	var pool *pgxpool.Pool
	pool, err = database.Connect(cfg.DatabaseUrl)

	if err != nil {
		log.Fatal("Failed to connect to the database", err)
	}

	defer pool.Close() // Close the database connection

	// Initialize Gin
	var router *gin.Engine = gin.Default()

	// Set trusted proxies
	router.SetTrustedProxies(nil)

	// Default Route
	router.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "GIN API is running",
			"status":  "success",
		})
	})

	router.POST("/todo", handlers.CreateTodoHandler(pool))

	router.GET("/todos", handlers.GetAllTodosHandler(pool))

	// Run the server
	router.Run(":" + cfg.Port)
}
