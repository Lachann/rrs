package main

import (
	"fmt"
	"os"
	"strconv"

	"github.com/Lachann/rrs/pkg/server"
)

var defaultPreviews = []string{
	"Slackbot",
	"Discordbot",
}

const defaultRickroll = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

func main() {
	host := os.Getenv("RRS_HOST")
	if host == "" {
		panic("RRS_HOST not set")
	}

	rickrollChance := os.Getenv("RRS_RICKROLL_CHANCE")
	if rickrollChance == "" {
		panic("RRS_RICKROLL_CHANCE not set")
	}
	chance, err := strconv.Atoi(rickrollChance)
	if err != nil {
		panic("RRS_RICKROLL_CHANCE must be an integer")
	}
	if chance < 30 || chance > 70 {
		panic("RRS_RICKROLL_CHANCE must be between 30 and 70")
	}

	if err := server.Start(host, defaultRickroll, defaultPreviews); err != nil {
		fmt.Println("Error starting server: ", err)
	}
}
