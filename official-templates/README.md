# PyTorch 2.8.0 Launch Spec 说明文档

## 一、用途说明

该 SQL 语句用于向 `saas_platform.tb_launch_spec` 表中注册一个 **官方 PyTorch 2.8.0 容器启动规格（Launch Spec）**，
使其可以在 Yotta SaaS 平台中作为 **可选镜像模板** 被用户直接创建实例。

该 Launch Spec 主要面向：

- AI / 深度学习训练与推理
- Jupyter Notebook 交互式开发
- Diffusion / ComfyUI / LLM 推理环境
- 通用 GPU 计算工作负载

---

## 二、对应 INSERT 语句说明

该 INSERT 语句完整描述了一个 **PyTorch 2.8.0 GPU 镜像的运行规范**，包含镜像信息、运行参数、端口暴露、环境变量及平台控制字段。

---

## 三、核心字段说明（结合表结构）

### 1. 基本元信息

- `id`：Launch Spec 唯一 ID  
- `org_id`：所属组织 ID  
- `creator_id`：创建人用户 ID  
- `name`：启动规格名称（UI 展示）  
- `description`：镜像用途描述  
- `tags`：标签（JSONB），用于分类与筛选  
- `cover_url`：UI 展示用封面图  

---

### 2. 镜像与仓库信息

- `image`：实际使用的 Docker Image  
- `docker_url`：Docker Hub 镜像说明页  
- `image_registry_type`：镜像仓库类型（1 = Docker Hub）  
- `image_registry`：自定义仓库地址（为空表示默认）  
- `image_type`：镜像类型（1 = Public）  
- `image_size`：镜像大小（GB）  
- `last_update_at`：镜像最后更新时间（epoch millis）  

---

### 3. 容器运行配置

- `container_volume`：容器系统盘大小（GB）  
- `persistent_volumes`：持久化卷定义（JSONB）  
- `init_command`：容器启动时执行的初始化命令  
- `ssh_user`：SSH 默认登录用户  
- `env_vars`：环境变量（JSONB）  
- `exposes`：对外暴露端口（JSONB）  

#### 当前端口定义

- 22 → SSH 远程登录  
- 8888 → Jupyter Notebook  

---

### 4. 平台控制字段

- `source_type`：来源类型（1 = Official）  
- `status`：状态（1 = enabled）  
- `deleted`：逻辑删除标志（0 = normal）  
- `popularity`：排序权重  
- `created_at` / `updated_at`：创建 / 更新时间戳（epoch millis）  

---

## 四、内置文档（doc 字段）

`doc` 字段中存放 Markdown 格式的镜像说明文档，用于在平台 UI 中展示，包括：

- PyTorch / CUDA / Python 版本信息  
- 使用场景说明  
- 常见服务端口  
- 推荐部署方式  

Launch Spec 本身即为 **自描述镜像模板**，无需依赖外部文档。

---

## 五、镜像构建与推送说明

该镜像通过 **Docker Buildx Bake** 构建并推送至公司镜像仓库。

### 标准构建与推送命令

```bash
docker buildx bake pytorch290 --no-cache --push
```

### 说明

- `pytorch290`：在 `docker-bake.hcl` 中定义的构建目标  
- `--no-cache`：强制全量重新构建  
- `--push`：构建完成后直接推送到公司镜像仓库  

### 推荐流程

1. 执行 buildx bake 构建并推送镜像  
2. 更新 `tb_launch_spec.image` 标签  
3. 同步更新：
   - `image_size`
   - `last_update_at`
   - `doc`（如有版本说明变更）

---

## 六、总结

该记录用于在 SaaS 平台中注册一个 **可直接使用的 PyTorch 2.8.0 官方 GPU 运行模板**，完整描述了：

- 镜像来源与版本
- 容器运行与初始化方式
- 网络与端口暴露
- 平台治理与状态控制

该 Launch Spec 可作为后续官方镜像（TensorFlow / vLLM / ComfyUI 等）的标准模板。
