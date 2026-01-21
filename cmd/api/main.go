package main

import (
	"github.com/gin-gonic/gin"
)

func main() {
	var router *gin.Engine = gin.Default()

	router.SetTrustedProxies([]string{"localhost"})

	// Default Route
	router.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "GI API is running",
			"status": "success",
		})
	})

	router.Run(":8000")
}
