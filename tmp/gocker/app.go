package main

import (
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
)

func check(err error) {
	if err != nil {
		log.Println(err)
	}
}

func cg() {
	cgPath := "/sys/fs/cgroup/"
	pidsPath := filepath.Join(cgPath, "pids")
	// 在 /sys/fs/cgroup/pids 下创建 container 目录
	check(os.Mkdir(filepath.Join(pidsPath, "js"), 0755))
	// 设置最大进程数目为 20
	check(ioutil.WriteFile(filepath.Join(pidsPath, "js/pids.max"), []byte("20"), 0700))
	// 将 notify_on_release 值设为 1，当 cgroup 不再包含任何任务的时候将执行 release_agent 的内容
	check(ioutil.WriteFile(filepath.Join(pidsPath, "js/notify_on_release"), []byte("1"), 0700))
	// 加入当前正在执行的进程
	check(ioutil.WriteFile(filepath.Join(pidsPath, "js/tasks"), []byte(strconv.Itoa(os.Getpid())), 0700))
}

// go run app.go sh
func main() {
	cmd := exec.Command(os.Args[1])
	cg()
	cmd.Stdin = os.Stdin
}
