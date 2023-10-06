package main

import (
	"fmt"
	"os"

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

	if err := server.Start(host, defaultRickroll, defaultPreviews); err != nil {
		fmt.Println("Error starting server: ", err)
	}
}
