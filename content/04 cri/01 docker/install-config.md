添加 docker 组

```
sudo groupadd docker
```

用户加入 docker 组

```
sudo usermod -aG docker ${USER}
```

重启 docker 服务

```
sudo systemctl restart docker
```

