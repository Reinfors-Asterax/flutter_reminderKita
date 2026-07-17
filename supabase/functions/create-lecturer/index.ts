import { createClient } from "supabase";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const jsonResponse = (
  body: Record<string, unknown>,
  status = 200,
): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ message: "Method tidak diizinkan." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("Authorization");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse({ message: "Konfigurasi server belum lengkap." }, 500);
  }
  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ message: "Sesi login tidak ditemukan." }, 401);
  }

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const token = authorization.replace("Bearer ", "");
  const {
    data: { user: caller },
    error: callerError,
  } = await callerClient.auth.getUser(token);

  if (callerError || !caller) {
    return jsonResponse({ message: "Sesi login tidak valid." }, 401);
  }

  const { data: callerProfile, error: profileError } = await adminClient
    .from("profiles")
    .select("role")
    .eq("id", caller.id)
    .maybeSingle();

  if (profileError) {
    return jsonResponse({ message: "Gagal memverifikasi role Admin." }, 500);
  }
  if (callerProfile?.role !== "admin") {
    return jsonResponse(
      { message: "Hanya Admin yang dapat membuat akun dosen." },
      403,
    );
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ message: "Payload tidak valid." }, 400);
  }

  const name = payload.name?.toString().trim() ?? "";
  const lecturerNumber = payload.lecturerNumber?.toString().trim() ?? "";
  const email = payload.email?.toString().trim().toLowerCase() ?? "";
  const password = payload.password?.toString() ?? "";

  if (!name || !lecturerNumber || !email || !password) {
    return jsonResponse({ message: "Semua data dosen wajib diisi." }, 400);
  }
  if (!email.includes("@")) {
    return jsonResponse({ message: "Format email tidak valid." }, 400);
  }
  if (password.length < 8) {
    return jsonResponse({ message: "Password minimal 8 karakter." }, 400);
  }

  const { data: created, error: createError } = await adminClient.auth.admin
    .createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        name,
        nim: lecturerNumber,
        role: "lecturer",
      },
    });

  if (createError || !created.user) {
    const message = createError?.message.toLowerCase().includes("registered")
      ? "Email sudah terdaftar."
      : createError?.message ?? "Gagal membuat akun Auth.";
    return jsonResponse({ message }, 422);
  }

  const { error: updateError } = await adminClient
    .from("profiles")
    .update({
      display_name: name,
      student_number: lecturerNumber,
      role: "lecturer",
      requested_role: null,
      approval_status: "active",
    })
    .eq("id", created.user.id);

  if (updateError) {
    await adminClient.auth.admin.deleteUser(created.user.id);
    return jsonResponse(
      { message: "Profil dosen gagal dibuat. Akun dibatalkan." },
      500,
    );
  }

  return jsonResponse(
    {
      id: created.user.id,
      email,
      name,
      role: "lecturer",
    },
    201,
  );
});
