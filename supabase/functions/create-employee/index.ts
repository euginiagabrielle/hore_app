import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Wajib ada CORS agar Flutter bisa memanggil fungsi ini
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle preflight request dari Flutter
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Ambil data yang dikirim dari aplikasi Flutter
    const { email, password, nip, name, role } = await req.json()

    // 2. Buat Supabase Client khusus Admin (Service Role)
    // Deno.env otomatis mengambil API URL dan Key rahasia dari server Supabase
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 3. Buat User di sistem Autentikasi Supabase (auth.users)
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true // Otomatis terkonfirmasi agar bisa langsung login
    })

    if (authError) throw authError

    // 4. Masukkan profilnya ke tabel public.employees
    const isTrusted = role === 'admin' || role === 'owner'
    const { error: dbError } = await supabaseAdmin.from('employees').insert({
      auth_user_id: authData.user.id,
      nip: nip,
      employee_name: name,
      employee_role: role,
      is_employee_active: true,
      is_trusted: isTrusted
    })

    if (dbError) throw dbError

    // 5. Berikan respon sukses ke Flutter
    return new Response(
      JSON.stringify({ message: 'Pegawai berhasil dibuat!' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})