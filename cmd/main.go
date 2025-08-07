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

const defaultHost = ":8080"

// get env var RRS_USE_BACKUP_URL
var useBackup = os.Getenv("RRS_USE_BACKUP_URL")

// const defaultRickroll = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
const defaultRickroll = "https://www.youtube.com/watch?v=tae8F4gkfiw"
// const defaultRickroll = "https://www.youtube.com/watch?v=LpNVf8sczqU"
// const defaultRickroll = "https://www.youtube.com/watch?v=oEtmFgonY3E"
const backupRickroll = "https://www.youtube.com/watch?v=knOXppaqBYY"

func main() {
	var rickroll string
	if useBackup == "true" {
		rickroll = backupRickroll
	} else {
		rickroll = defaultRickroll
	}
	if err := server.Start(defaultHost, rickroll, defaultPreviews); err != nil {
		fmt.Println("Error starting server: ", err)
	}
}
